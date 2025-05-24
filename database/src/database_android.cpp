//
// Created by kibi on 25-5-17.
//

#include <unistd.h> // 用于Android文件操作
#define PLATFORM_ANDROID 1

// 仅Android平台编译此代码
std::string get_package_name() {
    std::ifstream cmdline("/proc/self/cmdline");
    std::string package_name;
    std::getline(cmdline, package_name, '\0'); // 读取包名（进程名）
    return package_name;
}

std::string get_database_path() {
    std::string package_name = get_package_name();
    std::string db_dir = "/data/data/" + package_name + "/databases/";

    // 创建目录（如果不存在）
    mkdir(db_dir.c_str(), 0755);

    return db_dir + "tasks.db";
}