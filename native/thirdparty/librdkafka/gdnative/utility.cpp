#include <stdio.h>
#include <iostream>
#include <fstream>
#include <algorithm>
#include "./utility.h"

/**
 * @brief Reads a file and returns contents as string.
 * 
 * @param path 
 * @return std::string
 */
std::string readFile4(const std::string& filename)
{
    std::ifstream infile(filename.c_str());

    std::string data;
    data.reserve(infile.tellg());
    infile.seekg(0, std::ios::beg);
    data.append(std::istreambuf_iterator<char>(infile.rdbuf()),
                std::istreambuf_iterator<char>());
    // std::cout << data; // Debugging only
    return data;
}

std::string toLower(const std::string& data)
{
    std::for_each(data.begin(), data.end(), [](char & c) {
        c = ::toupper(c);
    });

    return data;
}