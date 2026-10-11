#pragma once

#include <array>
#include <cstdint>
#include <iosfwd>
#include <map>
#include <optional>
#include <string>
#include <utility>
#include <vector>

namespace mini {

using Id = std::uint64_t;

struct Vec3 {
    double x{}, y{}, z{};
    bool operator==(const Vec3&) const = default;
};

Vec3 operator+(Vec3 a, Vec3 b);

struct Mesh {
    std::string name;
    std::vector<Vec3> positions;
    std::vector<std::array<std::uint32_t, 3>> triangles;
};

struct Object {
    std::string name;
    Id mesh_id{};
    Vec3 translation;
};

// Authoring data. No GPU handles, cached world vertices, or undo stacks.
struct Scene {
    Id next_id{1};
    std::map<Id, Mesh> meshes;
    std::map<Id, Object> objects;

    Id add_mesh(Mesh mesh);
    Id add_object(std::string name, Id mesh_id, Vec3 translation = {});
};

void validate(const Scene& scene);
void write_scene(const Scene& scene, std::ostream& output);
Scene read_scene(std::istream& input);

class Command {
public:
    virtual ~Command() = default;
    virtual void apply(Scene& candidate) const = 0;
};

class Translate final : public Command {
public:
    Translate(Id object_id, Vec3 delta) : object_id_(object_id), delta_(delta) {}
    void apply(Scene& candidate) const override;
private:
    Id object_id_;
    Vec3 delta_;
};

class RemoveObject final : public Command {
public:
    explicit RemoveObject(Id object_id) : object_id_(object_id) {}
    void apply(Scene& candidate) const override;
private:
    Id object_id_;
};

struct RenderItem {
    Id object_id{};
    Id mesh_id{};
    std::vector<Vec3> world_positions;
};

struct EvaluatedScene {
    std::uint64_t revision{};
    std::vector<RenderItem> items;
};

class Document {
public:
    explicit Document(Scene scene = {});
    const Scene& scene() const { return scene_; }
    std::uint64_t revision() const { return revision_; }
    std::size_t evaluation_count() const { return evaluation_count_; }

    void execute(const Command& command);
    bool undo();
    bool redo();
    void save(std::ostream& output) const;
    void load(std::istream& input);
    // Borrowed reference: use only until the next document mutation/evaluation.
    const EvaluatedScene& evaluate() const;

private:
    Scene scene_;
    std::vector<Scene> undo_;
    std::vector<Scene> redo_;
    std::uint64_t revision_{};
    mutable std::optional<EvaluatedScene> evaluated_;
    mutable std::size_t evaluation_count_{};
};

} // namespace mini
