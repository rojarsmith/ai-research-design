#include "core.hpp"

#include <functional>
#include <iostream>
#include <limits>
#include <sstream>
#include <stdexcept>

namespace {
void require(bool condition, const char* message) {
    if (!condition) throw std::runtime_error(message);
}

template<class Function>
void require_error(Function function) {
    bool rejected = false;
    try { function(); }
    catch (const std::exception&) { rejected = true; }
    require(rejected, "Expected rejected operation");
}

struct Fixture {
    mini::Scene scene;
    mini::Id mesh, first, second;
    Fixture() {
        mesh = scene.add_mesh({"共享 Mesh \"with quotes\"", {{0,0,0},{1,0,0},{0,1,0}}, {{0,1,2}}});
        first = scene.add_object("First", mesh);
        second = scene.add_object("Second", mesh, {4,0,0});
    }
};

std::string saved(const mini::Document& document) {
    std::ostringstream output;
    document.save(output);
    return output.str();
}
} // namespace

int main() {
    const std::vector<std::pair<const char*, std::function<void()>>> cases{
        {"Instances keep shared authoring mesh", [] {
            Fixture f; mini::Document d{f.scene};
            d.execute(mini::Translate{f.first, {2,0,0}});
            const auto& items = d.evaluate().items;
            require(items[0].world_positions[0].x == 2, "First instance not moved");
            require(items[1].world_positions[0].x == 4, "Second instance changed");
            require(d.scene().meshes.at(f.mesh).positions[0].x == 0, "Authoring mesh changed");
        }},
        {"Cache invalidates after move undo and redo", [] {
            Fixture f; mini::Document d{f.scene};
            d.evaluate(); d.evaluate();
            require(d.evaluation_count() == 1, "Unchanged scene recomputed");
            d.execute(mini::Translate{f.first, {2,0,0}}); d.evaluate();
            require(d.undo(), "Undo unavailable");
            require(d.evaluate().items[0].world_positions[0].x == 0, "Undo cache stale");
            require(d.redo(), "Redo unavailable");
            require(d.evaluate().items[0].world_positions[0].x == 2, "Redo cache stale");
            require(d.evaluation_count() == 4 && d.revision() == 3, "Revision/cache count wrong");
        }},
        {"Editing after undo discards abandoned redo branch", [] {
            Fixture f; mini::Document d{f.scene};
            d.execute(mini::Translate{f.first, {2,0,0}}); d.undo();
            d.execute(mini::Translate{f.first, {0,3,0}});
            require(!d.redo(), "Abandoned history remained");
            require(d.scene().objects.at(f.first).translation == mini::Vec3{0,3,0}, "New edit lost");
        }},
        {"Rejected edits preserve scene revision and redo", [] {
            Fixture f; mini::Document d{f.scene};
            d.execute(mini::Translate{f.first, {2,0,0}}); d.undo();
            const auto before = saved(d); const auto revision = d.revision();
            require_error([&] { d.execute(mini::Translate{999, {1,0,0}}); });
            require_error([&] { d.execute(mini::Translate{f.first,
                {std::numeric_limits<double>::infinity(),0,0}}); });
            require(saved(d) == before && d.revision() == revision, "Failed edit changed document");
            require(d.redo(), "Failed edit consumed redo");
        }},
        {"Deletion undo restores the object and reference", [] {
            Fixture f; mini::Document d{f.scene};
            d.execute(mini::RemoveObject{f.first});
            require(d.scene().objects.size() == 1, "Deletion failed");
            d.undo();
            require(d.scene().objects.at(f.first).mesh_id == f.mesh, "Undo lost mesh reference");
        }},
        {"Issued IDs are not recycled after undo and a new edit", [] {
            struct CreateInstance final : mini::Command {
                mini::Id mesh;
                explicit CreateInstance(mini::Id id) : mesh(id) {}
                void apply(mini::Scene& scene) const override {
                    scene.add_object("New instance", mesh);
                }
            };
            Fixture f; mini::Document d{f.scene};
            d.execute(CreateInstance{f.mesh});
            const auto prior_id = d.scene().objects.rbegin()->first;
            d.undo(); d.execute(CreateInstance{f.mesh});
            const auto next_id = d.scene().objects.rbegin()->first;
            require(next_id > prior_id && !d.redo(), "An old object ID was recycled");
        }},
        {"Persistence preserves IDs names precision and shared references", [] {
            Fixture f; mini::Document d{f.scene};
            d.execute(mini::Translate{f.first, {0.12345678901234567,0,0}});
            const auto text = saved(d); std::istringstream input{text};
            mini::Document reopened; reopened.load(input);
            require(saved(reopened) == text, "Roundtrip changed authoring data");
            require(reopened.scene().objects.at(f.second).mesh_id == f.mesh, "Shared mesh lost");
            require(!reopened.undo(), "Runtime history was persisted");
        }},
        {"Loading is transactional and invalidates existing cache/history", [] {
            Fixture f; mini::Document d{f.scene};
            d.execute(mini::Translate{f.first, {2,0,0}}); d.evaluate();
            const auto before = saved(d); const auto revision = d.revision();
            std::istringstream broken{"MINI_SCENE 1 NEXT 5 MESHES 1 MESH"};
            require_error([&] { d.load(broken); });
            require(saved(d) == before && d.revision() == revision, "Broken load changed document");
            require(d.undo(), "Broken load cleared history");
            const auto text = saved(mini::Document{f.scene}); std::istringstream good{text};
            const auto prior_revision = d.revision(); d.load(good);
            require(d.revision() > prior_revision && !d.undo() && !d.redo(), "Load lifecycle wrong");
            require(d.evaluate().items[0].world_positions[0].x == 0, "Loaded cache stale");
        }},
        {"Version trailing data and section limits are checked", [] {
            for (const auto* text : {"MINI_SCENE 2", "MINI_SCENE 1 NEXT -1",
                 "MINI_SCENE 1 NEXT 1 MESHES -1", "MINI_SCENE 1 NEXT 1 MESHES 100001",
                 "MINI_SCENE 1 NEXT 1 MESHES 0 OBJECTS 0 END garbage"}) {
                std::istringstream input{text}; require_error([&] { mini::read_scene(input); });
            }
        }},
        {"Duplicate IDs broken links and topology are rejected", [] {
            Fixture f;
            auto bad = f.scene; bad.objects.at(f.first).mesh_id = 999;
            require_error([&] { mini::validate(bad); });
            bad = f.scene; bad.meshes.at(f.mesh).triangles[0][0] = 99;
            require_error([&] { mini::validate(bad); });
            bad = f.scene; bad.next_id = f.second;
            require_error([&] { mini::validate(bad); });
            bad = f.scene; bad.objects.emplace(f.mesh, bad.objects.at(f.first));
            require_error([&] { mini::validate(bad); });
        }},
        {"Empty history and empty scene are valid", [] {
            mini::Document d; require(!d.undo() && !d.redo(), "Empty history moved");
            std::istringstream input{saved(d)}; d.load(input);
            require(d.evaluate().items.empty(), "Empty scene gained objects");
        }}
    };
    std::size_t passed{};
    for (const auto& [name, test] : cases) {
        try { test(); ++passed; std::cout << "PASS " << name << '\n'; }
        catch (const std::exception& error) {
            std::cerr << "FAIL " << name << ": " << error.what() << '\n'; return 1;
        }
    }
    std::cout << passed << " workflow tests passed\n";
    return 0;
}
