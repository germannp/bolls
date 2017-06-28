// Print status and read and write Vtk legacy files, see
// http://www.vtk.org/wp-content/uploads/2015/04/file-formats.pdf
#pragma once

#include <time.h>
#include <sys/stat.h>
#include <assert.h>
#include <string>
#include <fstream>
#include <iostream>
#include <iomanip>
#include <sstream>
#include <typeinfo>
#include <vector>
#include <iterator>


template<typename Pt, int n_max, template<typename, int> class Solver>
class Solution;

template<int n_links>
class Links;

template<int n_max, typename Prop>
struct Property;


class Vtk_output {
public:
    // Files are stored as output/base_name_###.vtk
    Vtk_output(std::string base_name);
    ~Vtk_output(void);
    // Write x, y, and z component of Pt; has to be written first
    template<typename Pt, int n_max, template<typename, int> class Solver>
    void write_positions(Solution<Pt, n_max, Solver>& bolls);
    // Write links, see links.cuh; if written has to be second
    template<int n_links>
    void write_links(Links<n_links>& links);
    // Write further components of Pt
    template<typename Pt, int n_max, template<typename, int> class Solver>
    void write_field(Solution<Pt, n_max, Solver>& bolls,
        const char* data_name = "w", float Pt::*field = &Pt::w);
    // Write polarity from phi and theta of Pt, see polarity.cuh
    template<typename Pt, int n_max, template<typename, int> class Solver>
    void write_polarity(Solution<Pt, n_max, Solver>& bolls);
    // Write not integrated property, see property.cuh
    template<int n_max, typename Prop>
    void write_property(Property<n_max, Prop>& property);

protected:
    int n_bolls;
    int time_step = 0;
    std::string base_name;
    std::string current_path;
    bool point_data_started;
    time_t t_0;
};

Vtk_output::Vtk_output(std::string name) {
    base_name = name;
    mkdir("output", 755);
    time(&t_0);
}

Vtk_output::~Vtk_output() {
    auto t_f = time(NULL);
    auto duration = t_f - t_0;
    std::cout << "Integrating " << base_name << ", ";
    if (duration < 60)
        std::cout << duration << " seconds";
    else if (duration < 60*60)
        std::cout << duration/60 << "m " << duration % 60 << "s";
    else
        std::cout << duration/60/60 << "h " << duration % 60*60 << "m";
    std::cout << " taken (" << n_bolls << " bolls).        \n";  // Overwrite everything
}

template<typename Pt, int n_max, template<typename, int> class Solver>
void Vtk_output::write_positions(Solution<Pt, n_max, Solver>& bolls) {
    n_bolls = *bolls.h_n;
    assert(n_bolls <= n_max);

    std::cout << "Integrating " << base_name << ", ";
    std::cout << time_step << " steps done (" << n_bolls << " bolls)        \r";
    std::cout.flush();
    point_data_started = false;
    time_step += 1;

    current_path = "output/" + base_name + "_" + std::to_string(time_step)
        + ".vtk";
    std::ofstream file(current_path);
    assert(file.is_open());

    file << "# vtk DataFile Version 3.0\n";
    file << base_name << "\n";
    file << "ASCII\n";
    file << "DATASET POLYDATA\n";

    file << "\nPOINTS " << n_bolls << " float\n";
    for (auto i = 0; i < n_bolls; i++)
        file << bolls.h_X[i].x << " " << bolls.h_X[i].y << " " << bolls.h_X[i].z << "\n";

    file << "\nVERTICES " << n_bolls << " " << 2*n_bolls << "\n";
    for (auto i = 0; i < n_bolls; i++)
        file << "1 " << i << "\n";
}

template<int n_links>
void Vtk_output::write_links(Links<n_links>& links) {
    std::ofstream file(current_path, std::ios_base::app);
    assert(file.is_open());

    file << "\nLINES " << *links.h_n << " " << 3**links.h_n << "\n";
    for (auto i = 0; i < *links.h_n; i++)
        file << "2 " << links.h_link[i].a << " " << links.h_link[i].b << "\n";
}

template<typename Pt, int n_max, template<typename, int> class Solver>
void Vtk_output::write_field(Solution<Pt, n_max, Solver>& bolls,
        const char* data_name, float Pt::*field) {
    std::ofstream file(current_path, std::ios_base::app);
    assert(file.is_open());

    if (!point_data_started) {
        file << "\nPOINT_DATA " << n_bolls << "\n";
        point_data_started = true;
    }
    file << "SCALARS " << data_name << " float\n";
    file << "LOOKUP_TABLE default\n";
    for (auto i = 0; i < n_bolls; i++)
        file << bolls.h_X[i].*field << "\n";
}

template<typename Pt, int n_max, template<typename, int> class Solver>
void Vtk_output::write_polarity(Solution<Pt, n_max, Solver>& bolls) {
    std::ofstream file(current_path, std::ios_base::app);
    assert(file.is_open());

    if (!point_data_started) {
        file << "\nPOINT_DATA " << n_bolls << "\n";
        point_data_started = true;
    }
    file << "NORMALS polarity float\n";
    for (auto i = 0; i < n_bolls; i++) {
        float3 n {0};
        if ((bolls.h_X[i].phi != 0) or (bolls.h_X[i].theta != 0)) {
            n.x = sinf(bolls.h_X[i].theta)*cosf(bolls.h_X[i].phi);
            n.y = sinf(bolls.h_X[i].theta)*sinf(bolls.h_X[i].phi);
            n.z = cosf(bolls.h_X[i].theta);
        }
        file << n.x << " " << n.y << " " << n.z << "\n";
    }
}

template<int n_max, typename Prop>
void Vtk_output::write_property(Property<n_max, Prop>& property) {
    std::ofstream file(current_path, std::ios_base::app);
    assert(file.is_open());

    if (!point_data_started) {
        file << "\nPOINT_DATA " << n_bolls << "\n";
        point_data_started = true;
    }

    std::string ptype = typeid(Prop).name();  // Check whether Prop is int or float
    if (ptype == "f") ptype = "float";        // to define the type in vtk format
    else ptype = "int";

    file << "SCALARS " << property.name << " " << ptype <<"\n";
    file << "LOOKUP_TABLE default\n";
    for (auto i = 0; i < n_bolls; i++)
        file << property.h_prop[i] << "\n";
}


// Files have to be read in the same order as they have been written.
class Vtk_input {
public:
    Vtk_input(std::string filename);
    template<typename Pt, int n_max, template<typename, int> class Solver>
    void read_positions(Solution<Pt, n_max, Solver>& bolls);
    // Read polarity of Pt, see polarity.cuh
    template<typename Pt, int n_max, template<typename, int> class Solver>
    void read_polarity(Solution<Pt, n_max, Solver>& bolls);
    // Read not integrated property, see property.cuh
    template<int n_max, typename Prop>
    void read_property(Property<n_max, Prop>& property);
    int n_bolls;

protected:
    std::streampos bookmark;
    std::string file_name;
};

// Split a string by whitespace adapted from:
// https://stackoverflow.com/questions/236129/split-a-string-in-c
template<typename Out> void split(const std::string &s, char delim, Out result) {
    if(s.length()==0) return;
    std::stringstream ss;
    ss.str(s);
    std::string item;
    while (std::getline(ss, item, delim)) {
        *(result++) = item;
    }
}

std::vector<std::string> split(const std::string &s, char delim) {
    std::vector<std::string> elems;
    split(s, delim, std::back_inserter(elems));
    return elems;
}

Vtk_input::Vtk_input(std::string filename) {
    file_name = filename;

    std::string line;
    std::ifstream input_file;
    std::vector<std::string> items;

    input_file.open(file_name, std::fstream::in);

    for (auto i = 0; i < 6; i++) getline(input_file, line);
    split(line, ' ', std::back_inserter(items));
    n_bolls = stoi(items[1]);
    items.clear();

    // Save the read position for later read functions
    bookmark = input_file.tellg();
}

template<typename Pt, int n_max, template<typename, int> class Solver>
void Vtk_input::read_positions(Solution<Pt, n_max, Solver>& bolls) {
    std::ifstream input_file(file_name);
    assert(input_file.is_open());

    // Set the read position to the last line read
    input_file.seekg(bookmark);

    std::string line;
    std::vector<std::string> items;

    // Read coordinates
    for (int i = 0; i < n_bolls; i++) {
        getline(input_file, line);
        split(line, ' ', std::back_inserter(items));
        bolls.h_X[i].x = stof(items[0]); bolls.h_X[i].y = stof(items[1]); bolls.h_X[i].z = stof(items[2]);
        items.clear();
    }

    getline(input_file, line); // Blank line
    getline(input_file, line);
    split(line, ' ', std::back_inserter(items));

    // Skip redundant list of vertices
    for (int i = 0; i < n_bolls; i++) getline(input_file, line);

    bookmark = input_file.tellg();
}

template<typename Pt, int n_max, template<typename, int> class Solver>
void Vtk_input::read_polarity(Solution<Pt, n_max, Solver>& bolls) {
    std::ifstream input_file(file_name);
    assert(input_file.is_open());

    input_file.seekg(bookmark);

    std::string line;
    std::vector<std::string> items;

    getline(input_file, line); // Blank line after positions data
    getline(input_file, line);
    split(line, ' ', std::back_inserter(items));
    items.clear();
    getline(input_file,line);
    split(line, ' ', std::back_inserter(items));
    items.clear();

    // Read normals
    for (auto i = 0; i < n_bolls; i++) {
        getline(input_file, line);
        split(line, ' ', std::back_inserter(items));
        items.clear();
        auto x = stof(items[0]); auto y = stof(items[1]); auto z = stof(items[2]);
        auto dist = sqrt(pow(x, 2) + pow(y, 2) + pow(z, 2));
        if(dist == 0) {
            bolls.h_X[i].phi = 0.0f;
            bolls.h_X[i].theta = 0.0f;
        } else {
            bolls.h_X[i].phi = atan2(y, x);
            bolls.h_X[i].theta = acos(z);  // The normals are unit vectors, so no need to divide by length
        }
    }

    bookmark = input_file.tellg();
}

template<int n_max, typename Prop>
void Vtk_input::read_property(Property<n_max, Prop>& property) {
    std::ifstream input_file(file_name);
    assert(input_file.is_open());

    input_file.seekg(bookmark);

    std::string line;
    std::vector<std::string> items;
    getline(input_file, line); // Property header line
    split(line, ' ', std::back_inserter(items));
    items.clear();

    getline(input_file,line); // Lookup table
    split(line, ' ', std::back_inserter(items));
    items.clear();

    for (int i=0 ; i<n_bolls ; i++) {
        getline(input_file,line);
        std::istringstream (line) >> property.h_prop[i] ;
    }

    bookmark = input_file.tellg();
}
