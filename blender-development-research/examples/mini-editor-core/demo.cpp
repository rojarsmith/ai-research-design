#include "core.hpp"

#include <fstream>
#include <iostream>
#include <sstream>
#include <stdexcept>

int main(int argc, char** argv) {
    try {
        mini::Scene scene;
        const auto mesh = scene.add_mesh({"Shared cube",
            {{-1,-1,-1},{1,-1,-1},{1,1,-1},{-1,1,-1},
             {-1,-1,1},{1,-1,1},{1,1,1},{-1,1,1}},
            {{0,2,1},{0,3,2},{4,5,6},{4,6,7},{0,1,5},{0,5,4},
             {2,3,7},{2,7,6},{1,2,6},{1,6,5},{3,0,4},{3,4,7}}});
        const auto first = scene.add_object("Cube A", mesh);
        scene.add_object("Cube B", mesh, {4,0,0});
        mini::Document document{std::move(scene)};
        auto show = [&](const char* label) {
            const auto& evaluated = document.evaluate();
            const auto first_vertex = evaluated.items.front().world_positions.front();
            std::cout << label << ": revision=" << document.revision()
                      << ", first_vertex.x=" << first_vertex.x
                      << ", evaluations=" << document.evaluation_count() << '\n';
        };
        show("Initial");
        show("Unchanged frame uses cache");
        document.execute(mini::Translate{first, {2,0,0}});
        show("Move");
        document.undo();
        show("Undo");
        document.redo();
        show("Redo");

        std::stringstream serialized;
        document.save(serialized);
        mini::Document reopened;
        reopened.load(serialized);
        const auto& object = reopened.scene().objects.at(first);
        if (object.translation != mini::Vec3{2,0,0}) {
            throw std::runtime_error("Roundtrip changed object transform");
        }
        std::cout << "Roundtrip: two objects share one mesh; runtime state is rebuilt.\n";
        if (argc == 2) {
            // Simple export for inspection. A production save needs atomic replacement.
            std::ofstream output(argv[1], std::ios::binary);
            document.save(output);
            output.close();
            if (!output) throw std::runtime_error("File close failed");
            std::cout << "Saved scene to " << argv[1] << '\n';
        } else if (argc != 1) {
            throw std::runtime_error("Usage: editor_demo [output.scene]");
        }
        return 0;
    } catch (const std::exception& error) {
        std::cerr << error.what() << '\n';
        return 1;
    }
}
