#include "core.hpp"

#include <algorithm>
#include <charconv>
#include <cmath>
#include <iomanip>
#include <istream>
#include <limits>
#include <locale>
#include <ostream>
#include <set>
#include <stdexcept>

namespace mini {
namespace {

bool finite(Vec3 value) {
    return std::isfinite(value.x) && std::isfinite(value.y) && std::isfinite(value.z);
}

Id allocate(Scene& scene) {
    if (scene.next_id == 0 || scene.next_id == std::numeric_limits<Id>::max()) {
        throw std::runtime_error("ID space exhausted");
    }
    return scene.next_id++;
}

void expect(std::istream& input, const char* expected) {
    std::string token;
    if (!(input >> token) || token != expected) {
        throw std::runtime_error(std::string("Expected token: ") + expected);
    }
}

std::uint64_t read_unsigned(std::istream& input) {
    std::string token;
    if (!(input >> token)) throw std::runtime_error("Missing unsigned integer");
    std::uint64_t value{};
    const auto result = std::from_chars(token.data(), token.data() + token.size(), value);
    if (result.ec != std::errc{} || result.ptr != token.data() + token.size()) {
        throw std::runtime_error("Invalid unsigned integer");
    }
    return value;
}

std::size_t read_count(std::istream& input) {
    // Per-section limit for this small teaching format, not a total memory budget.
    const auto count = read_unsigned(input);
    if (count > 100000) {
        throw std::runtime_error("Invalid or excessive element count");
    }
    return static_cast<std::size_t>(count);
}

} // namespace

Vec3 operator+(Vec3 a, Vec3 b) {
    return {a.x + b.x, a.y + b.y, a.z + b.z};
}

Id Scene::add_mesh(Mesh mesh) {
    const Id id = allocate(*this);
    if (!meshes.emplace(id, std::move(mesh)).second) {
        throw std::runtime_error("Duplicate mesh ID");
    }
    return id;
}

Id Scene::add_object(std::string name, Id mesh_id, Vec3 translation) {
    if (!meshes.contains(mesh_id) || !finite(translation)) {
        throw std::runtime_error("Invalid object input");
    }
    const Id id = allocate(*this);
    if (!objects.emplace(id, Object{std::move(name), mesh_id, translation}).second) {
        throw std::runtime_error("Duplicate object ID");
    }
    return id;
}

void validate(const Scene& scene) {
    if (scene.next_id == 0) {
        throw std::runtime_error("Invalid next ID");
    }
    std::set<Id> ids;
    auto check_id = [&](Id id) {
        if (id == 0 || id >= scene.next_id || !ids.insert(id).second) {
            throw std::runtime_error("Invalid or duplicate persistent ID");
        }
    };
    for (const auto& [id, mesh] : scene.meshes) {
        check_id(id);
        for (const auto position : mesh.positions) {
            if (!finite(position)) {
                throw std::runtime_error("Non-finite mesh position");
            }
        }
        for (const auto& triangle : mesh.triangles) {
            for (const auto index : triangle) {
                if (index >= mesh.positions.size()) {
                    throw std::runtime_error("Triangle index out of range");
                }
            }
        }
    }
    for (const auto& [id, object] : scene.objects) {
        check_id(id);
        if (!scene.meshes.contains(object.mesh_id) || !finite(object.translation)) {
            throw std::runtime_error("Dangling mesh reference or invalid transform");
        }
    }
}

void write_scene(const Scene& scene, std::ostream& output) {
    validate(scene);
    output.imbue(std::locale::classic());
    output << std::setprecision(std::numeric_limits<double>::max_digits10);
    output << "MINI_SCENE 1\nNEXT " << scene.next_id << "\nMESHES " << scene.meshes.size() << '\n';
    for (const auto& [id, mesh] : scene.meshes) {
        output << "MESH " << id << ' ' << std::quoted(mesh.name) << '\n';
        output << "VERTICES " << mesh.positions.size() << '\n';
        for (const auto v : mesh.positions) {
            output << v.x << ' ' << v.y << ' ' << v.z << '\n';
        }
        output << "TRIANGLES " << mesh.triangles.size() << '\n';
        for (const auto& triangle : mesh.triangles) {
            output << triangle[0] << ' ' << triangle[1] << ' ' << triangle[2] << '\n';
        }
    }
    output << "OBJECTS " << scene.objects.size() << '\n';
    for (const auto& [id, object] : scene.objects) {
        const auto t = object.translation;
        output << "OBJECT " << id << ' ' << object.mesh_id << ' ' << std::quoted(object.name)
               << ' ' << t.x << ' ' << t.y << ' ' << t.z << '\n';
    }
    output << "END\n";
    if (!output) {
        throw std::runtime_error("Scene write failed");
    }
}

Scene read_scene(std::istream& input) {
    input.imbue(std::locale::classic());
    expect(input, "MINI_SCENE");
    const auto version = read_unsigned(input);
    if (version != 1) {
        throw std::runtime_error("Unsupported scene version");
    }
    Scene scene;
    expect(input, "NEXT");
    scene.next_id = read_unsigned(input);
    expect(input, "MESHES");
    const auto mesh_count = read_count(input);
    for (std::size_t m = 0; m < mesh_count; ++m) {
        expect(input, "MESH");
        const Id id = read_unsigned(input);
        Mesh mesh;
        if (!(input >> std::quoted(mesh.name))) {
            throw std::runtime_error("Invalid mesh header");
        }
        expect(input, "VERTICES");
        mesh.positions.resize(read_count(input));
        for (auto& v : mesh.positions) {
            if (!(input >> v.x >> v.y >> v.z)) {
                throw std::runtime_error("Invalid vertex");
            }
        }
        expect(input, "TRIANGLES");
        mesh.triangles.resize(read_count(input));
        for (auto& triangle : mesh.triangles) {
            if (!(input >> triangle[0] >> triangle[1] >> triangle[2])) {
                throw std::runtime_error("Invalid triangle");
            }
        }
        if (!scene.meshes.emplace(id, std::move(mesh)).second) {
            throw std::runtime_error("Duplicate mesh ID");
        }
    }
    expect(input, "OBJECTS");
    const auto object_count = read_count(input);
    for (std::size_t o = 0; o < object_count; ++o) {
        expect(input, "OBJECT");
        const Id id = read_unsigned(input);
        Object object;
        object.mesh_id = read_unsigned(input);
        auto& t = object.translation;
        if (!(input >> std::quoted(object.name) >> t.x >> t.y >> t.z)) {
            throw std::runtime_error("Invalid object");
        }
        if (!scene.objects.emplace(id, std::move(object)).second) {
            throw std::runtime_error("Duplicate object ID");
        }
    }
    expect(input, "END");
    input >> std::ws;
    if (!input.eof()) {
        throw std::runtime_error("Unexpected trailing data");
    }
    validate(scene);
    return scene;
}

void Translate::apply(Scene& candidate) const {
    auto& object = candidate.objects.at(object_id_);
    object.translation = object.translation + delta_;
}

void RemoveObject::apply(Scene& candidate) const {
    if (candidate.objects.erase(object_id_) != 1) {
        throw std::runtime_error("Object not found");
    }
}

Document::Document(Scene scene) : scene_(std::move(scene)) {
    validate(scene_);
}

void Document::execute(const Command& command) {
    Scene candidate = scene_;
    command.apply(candidate);
    validate(candidate);
    // Only a successful, validated operation enters history.
    undo_.push_back(scene_);
    scene_ = std::move(candidate);
    redo_.clear();
    ++revision_;
}

bool Document::undo() {
    if (undo_.empty()) return false;
    redo_.push_back(scene_);
    const auto next_id = scene_.next_id;
    scene_ = std::move(undo_.back());
    // Issued IDs cannot be recycled into a new history branch.
    scene_.next_id = std::max(scene_.next_id, next_id);
    undo_.pop_back();
    ++revision_;
    return true;
}

bool Document::redo() {
    if (redo_.empty()) return false;
    undo_.push_back(scene_);
    const auto next_id = scene_.next_id;
    scene_ = std::move(redo_.back());
    scene_.next_id = std::max(scene_.next_id, next_id);
    redo_.pop_back();
    ++revision_;
    return true;
}

void Document::save(std::ostream& output) const {
    write_scene(scene_, output);
}

void Document::load(std::istream& input) {
    Scene candidate = read_scene(input);
    // Parse and validate first; a broken file cannot replace the open document.
    scene_ = std::move(candidate);
    undo_.clear();
    redo_.clear();
    ++revision_;
}

const EvaluatedScene& Document::evaluate() const {
    if (evaluated_ && evaluated_->revision == revision_) {
        return *evaluated_;
    }
    EvaluatedScene evaluated;
    evaluated.revision = revision_;
    for (const auto& [id, object] : scene_.objects) {
        RenderItem item{id, object.mesh_id, {}};
        const auto& mesh = scene_.meshes.at(object.mesh_id);
        item.world_positions.reserve(mesh.positions.size());
        for (const auto position : mesh.positions) {
            const auto world = position + object.translation;
            if (!finite(world)) throw std::runtime_error("Evaluation overflow");
            item.world_positions.push_back(world);
        }
        evaluated.items.push_back(std::move(item));
    }
    evaluated_ = std::move(evaluated);
    ++evaluation_count_;
    return *evaluated_;
}

} // namespace mini
