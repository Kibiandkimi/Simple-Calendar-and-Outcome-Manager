
//
// Created by kibi on 24-12-7.
//
#define DOCTEST_CONFIG_IMPLEMENT_WITH_MAIN
#include "doctest.h"
#include "../database.h"
#include <set>

void fill_list(Database::TaskList *list) {
    list->title = "Test List";
}

void fill_task(Database::Task *task) {
    task->belong = 1;
    task->title = "Test Task";
    task->description = "Test description.";
    task->start_time = 0;
    task->end_time = 1000;
    task->status = 1;
}

TEST_SUITE("Database Test") {
    TEST_CASE("Database Test") {
        remove("test_task.db");
        Database db("test_task.db");

        SUBCASE("Test new list") {
            Database::TaskList* list;
            CHECK(db.new_task_list(list) == 0);
            delete list;
        }

        SUBCASE("Test add list") {
            Database::TaskList* list;
            db.new_task_list(list);
            fill_list(list);
            CHECK(db.add_task_list(list) == 0);
        }

        SUBCASE("Test new task") {
            Database::Task *task;
            CHECK(db.new_task(task) == 0);
            delete task;
        }

        SUBCASE("Test add task") {
            Database::Task *task;
            db.new_task(task);
            fill_task(task);
            CHECK(db.add_task(task) == 0);
        }

        SUBCASE("Test delete list") {
            Database::TaskList *list;
            db.new_task_list(list);
            fill_list(list);
            auto id = list->get_id();
            db.add_task_list(list);
            CHECK(db.delete_task_list(id) == 0);
        }

        SUBCASE("Test delete task") {
            Database::Task *task;
            db.new_task(task);
            fill_task(task);
            auto id = task->get_id();
            db.add_task(task);
            CHECK(db.delete_task(id) == 0);
        }

        SUBCASE("Test delete list with task") {
            Database::TaskList *list;
            db.new_task_list(list);
            fill_list(list);
            auto list_id = list->get_id();
            db.add_task_list(list);

            Database::Task *task;
            db.new_task(task);
            fill_task(task);
            task->belong = list_id;
            db.add_task(task);

            uint pre_task_num;
            db.query_task_num(pre_task_num);
            CHECK(db.delete_task_list(list_id) == 0);
            uint task_num;
            db.query_task_num(task_num);
            CHECK(pre_task_num == task_num + 1);
        }

        SUBCASE("Test query list") {
            Database::TaskList *list;
            db.new_task_list(list);
            list->title = "Test List i";
            auto id = list->get_id();
            db.add_task_list(list);
            Database::TaskList *res;
            CHECK(db.query_task_list(id, res) == 0);
            CHECK(res->get_id() == id);
            CHECK(res->title == "Test List i");
        }

        SUBCASE("Test query task") {
            Database::Task *task;
            db.new_task(task);
            auto id = task->get_id();
            task->belong = 2;
            task->title = "Test Task 2";
            task->description = "Test description 2";
            task->start_time = 114;
            task->end_time = 514;
            task->status = 2;
            db.add_task(task);
            Database::Task *res;
            CHECK(db.query_task(id, res) == 0);
            CHECK(res->get_id() == id);
            CHECK(res->title == "Test Task 2");
            CHECK(res->description == "Test description 2");
            CHECK(res->start_time == 114);
            CHECK(res->end_time == 514);
            CHECK(res->status == 2);
        }

        SUBCASE("Test list update") {
            Database::TaskList *list;
            db.new_task_list(list);
            fill_list(list);
            auto id = list->get_id();
            db.add_task_list(list);
            db.query_task_list(id, list);
            list->title = "Test List (new)";
            CHECK(db.update_task_list(*list) == 0);
            db.query_task_list(id, list);
            CHECK(list->title == "Test List (new)");
        }

        SUBCASE("Test task update") {
            Database::Task *task;
            db.new_task(task);
            fill_task(task);
            auto id = task->get_id();
            db.add_task(task);
            db.query_task(id, task);
            task->belong = 998244353;
            task->title = "Test Task (new)";
            task->description = "New description!";
            task->start_time = 1145141;
            task->end_time = 1000000007;
            task->status = 3;
            CHECK(db.update_task(*task) == 0);
            db.query_task(id, task);
            CHECK(task->belong == 998244353);
            CHECK(task->title == "Test Task (new)");
            CHECK(task->description == "New description!");
            CHECK(task->start_time == 1145141);
            CHECK(task->end_time == 1000000007);
            CHECK(task->status == 3);
        }

        SUBCASE("Test query list num") {
            uint pre_num;
            CHECK(db.query_task_list_num(pre_num) == 0);
            Database::TaskList *list;
            db.new_task_list(list);
            fill_list(list);
            db.add_task_list(list);
            uint num;
            CHECK(db.query_task_list_num(num) == 0);
            CHECK(num == pre_num + 1);
        }

        SUBCASE("Test query task num") {
            uint pre_num;
            CHECK(db.query_task_num(pre_num) == 0);
            Database::Task *task;
            db.new_task(task);
            fill_task(task);
            db.add_task(task);
            uint num;
            CHECK(db.query_task_num(num) == 0);
            CHECK(num == pre_num + 1);
        }

        remove("test_task2.db");
        Database db2("test_task2.db");

        SUBCASE("Test query all list") {
            Database::TaskList *list;
            db2.new_task_list(list);
            fill_list(list);
            db2.add_task_list(list);
            Database::TaskList *list2;
            db2.new_task_list(list2);
            fill_list(list2);
            db2.add_task_list(list2);
            vector<Database::TaskList> res;
            CHECK(db2.query_all_task_list(res) == 0);
            CHECK(res.size() == 2);
            CHECK(res[0].title == "Test List");
            CHECK(res[1].title == "Test List");
        }

        SUBCASE("Test query all task") {
            Database::Task *task;
            db2.new_task(task);
            fill_task(task);
            db2.add_task(task);
            Database::Task *task2;
            db2.new_task(task2);
            fill_task(task2);
            db2.add_task(task2);
            vector<Database::Task> res;
            CHECK(db2.query_all_task(res) == 0);
            CHECK(res.size() == 2);
            CHECK(res[0].title == "Test Task");
            CHECK(res[1].title == "Test Task");
        }
    }
}

// 新增的扩展测试用例
TEST_SUITE("Extended Database Tests") {
    TEST_CASE("UUID-based Operations Test") {
        remove("test_uuid.db");
        Database db("test_uuid.db");

        SUBCASE("Test delete task list by UUID") {
            Database::TaskList *list;
            db.new_task_list(list);
            fill_list(list);
            string uuid = list->get_uuid();
            db.add_task_list(list);
            CHECK(db.delete_task_list_by_uuid(uuid) == 0);
        }

        SUBCASE("Test delete task by UUID") {
            Database::Task *task;
            db.new_task(task);
            fill_task(task);
            string uuid = task->get_uuid();
            db.add_task(task);
            CHECK(db.delete_task_by_uuid(uuid) == 0);
        }

        SUBCASE("Test query task list by UUID") {
            Database::TaskList *list;
            db.new_task_list(list);
            list->title = "UUID Test List";
            string uuid = list->get_uuid();
            db.add_task_list(list);

            Database::TaskList *res;
            CHECK(db.query_task_list_by_uuid(uuid, res) == 0);
            CHECK(res->get_uuid() == uuid);
            CHECK(res->title == "UUID Test List");
        }

        SUBCASE("Test query task by UUID") {
            Database::Task *task;
            db.new_task(task);
            task->title = "UUID Test Task";
            task->description = "UUID description";
            string uuid = task->get_uuid();
            db.add_task(task);

            Database::Task *res;
            CHECK(db.query_task_by_uuid(uuid, res) == 0);
            CHECK(res->get_uuid() == uuid);
            CHECK(res->title == "UUID Test Task");
            CHECK(res->description == "UUID description");
        }
    }

    TEST_CASE("Edge Cases Test") {
        remove("test_edge.db");
        Database db("test_edge.db");

        SUBCASE("Test empty database queries") {
            uint list_num, task_num;
            CHECK(db.query_task_list_num(list_num) == 0);
            CHECK(list_num == 0);
            CHECK(db.query_task_num(task_num) == 0);
            CHECK(task_num == 0);

            vector<Database::TaskList> lists;
            vector<Database::Task> tasks;
            CHECK(db.query_all_task_list(lists) == 0);
            CHECK(lists.empty());
            CHECK(db.query_all_task(tasks) == 0);
            CHECK(tasks.empty());
        }

        SUBCASE("Test query non-existent items") {
            Database::TaskList *list;
            Database::Task *task;
            // 假设ID 999999不存在
            CHECK(db.query_task_list(999999, list) != 0);
            CHECK(db.query_task(999999, task) != 0);
            CHECK(db.query_task_list_by_uuid("non-existent-uuid", list) != 0);
            CHECK(db.query_task_by_uuid("non-existent-uuid", task) != 0);
        }

        SUBCASE("Test delete non-existent items") {
            CHECK(db.delete_task_list(999999) != 0);
            CHECK(db.delete_task(999999) != 0);
            CHECK(db.delete_task_list_by_uuid("non-existent-uuid") != 0);
            CHECK(db.delete_task_by_uuid("non-existent-uuid") != 0);
        }

        SUBCASE("Test task with empty/null values") {
            Database::Task *task;
            db.new_task(task);
            task->belong = 1;
            task->title = "";
            task->description = "";
            task->start_time = 0;
            task->end_time = 0;
            task->status = 0;
            CHECK(db.add_task(task) == 0);
        }

        SUBCASE("Test list with empty title") {
            Database::TaskList *list;
            db.new_task_list(list);
            list->title = "";
            CHECK(db.add_task_list(list) == 0);
        }
    }

    TEST_CASE("Performance and Stress Test") {
        remove("test_perf.db");
        Database db("test_perf.db");

        SUBCASE("Test multiple lists and tasks") {
            const int num_lists = 10;
            const int num_tasks_per_list = 5;

            vector<uint> list_ids;

            // 创建多个列表
            for (int i = 0; i < num_lists; i++) {
                Database::TaskList *list;
                db.new_task_list(list);
                list->title = "List " + std::to_string(i);
                auto id = list->get_id();
                list_ids.push_back(id);
                CHECK(db.add_task_list(list) == 0);
            }

            // 为每个列表创建多个任务
            for (int i = 0; i < num_lists; i++) {
                for (int j = 0; j < num_tasks_per_list; j++) {
                    Database::Task *task;
                    db.new_task(task);
                    task->belong = list_ids[i];
                    task->title = "Task " + std::to_string(i) + "-" + std::to_string(j);
                    task->description = "Description for task " + std::to_string(i) + "-" + std::to_string(j);
                    task->start_time = i * 1000 + j * 100;
                    task->end_time = i * 1000 + j * 100 + 50;
                    task->status = j % 3; // 状态在0-2之间循环
                    CHECK(db.add_task(task) == 0);
                }
            }

            // 验证创建的数量
            uint total_lists, total_tasks;
            CHECK(db.query_task_list_num(total_lists) == 0);
            CHECK(total_lists == num_lists);
            CHECK(db.query_task_num(total_tasks) == 0);
            CHECK(total_tasks == num_lists * num_tasks_per_list);

            // 查询所有数据
            vector<Database::TaskList> all_lists;
            vector<Database::Task> all_tasks;
            CHECK(db.query_all_task_list(all_lists) == 0);
            CHECK(all_lists.size() == num_lists);
            CHECK(db.query_all_task(all_tasks) == 0);
            CHECK(all_tasks.size() == num_lists * num_tasks_per_list);
        }
    }
}

// 扩展的Utility测试
TEST_SUITE("Utility Functions Test") {
    TEST_CASE("Time Conversion Test") {
        SUBCASE("Test time_to_string") {
            time_t test_time = 0; // Unix时间戳0 (1970-01-01 00:00:00 UTC)
            string time_str = Utility::time_to_string(test_time);
            CHECK_FALSE(time_str.empty());
        }

        SUBCASE("Test string_to_time") {
            string time_str = "1970-01-01 08:00:00"; // 假设的时间格式
            long long time_val = Utility::string_to_time(time_str);
            CHECK(time_val >= 0);
        }

        SUBCASE("Test round-trip time conversion") {
            time_t original_time = 1000000; // 任意时间戳
            string time_str = Utility::time_to_string(original_time);
            long long converted_time = Utility::string_to_time(time_str);
            // 允许小的误差，因为可能有精度损失
            CHECK(abs(static_cast<long long>(original_time) - converted_time) <= 1);
        }
    }

    TEST_CASE("Dart Conversion Test") {
        remove("test_dart_conv.db");
        Database db("test_dart_conv.db");

        SUBCASE("Test task_to_dart_task conversion") {
            Database::Task *task;
            db.new_task(task);
            task->belong = 1;
            task->title = "Dart Test Task";
            task->description = "Dart test description";
            task->start_time = 1000;
            task->end_time = 2000;
            task->status = 2;

            Dart_Task dart_task = Utility::task_to_dart_task(*task);
            CHECK(dart_task.list_id == 1);
            CHECK(string(dart_task.title) == "Dart Test Task");
            CHECK(string(dart_task.description) == "Dart test description");
            CHECK(dart_task.status == 2);
        }

        SUBCASE("Test list_to_dart_task_list conversion") {
            Database::TaskList *list;
            db.new_task_list(list);
            list->title = "Dart Test List";

            Dart_TaskList dart_list = Utility::list_to_dart_task_list(*list);
            CHECK(string(dart_list.title) == "Dart Test List");
        }
    }
}

// 扩展的Dart API测试
TEST_SUITE("Extended Dart API Test") {
    TEST_CASE("Dart Api CRUD Operations") {
        Dart_exit();

        remove("tasks.db");

        // 初始化
        CHECK(Dart_init() == 0);

        SUBCASE("Test Dart_create_tasklist") {
            int result = Dart_create_tasklist("New Dart List");
            CHECK(result == 1);
        }

        SUBCASE("Test Dart_create_task") {
            // 首先创建一个列表
            Dart_create_tasklist("Task List");
            int list_id = 1; // 假设第一个列表的ID为1

            int result = Dart_create_task(list_id, "New Task", "Task Description",
                                        "2024-01-01 10:00:00", "2024-01-01 11:00:00", 1);
            CHECK(result == 1);
        }

        SUBCASE("Test Dart query functions") {
            // 创建测试数据
            Dart_create_tasklist("Query Test List");
            Dart_create_task(1, "Query Test Task", "Description",
                           "2024-01-01 10:00:00", "2024-01-01 11:00:00", 1);

            // deprecated function
            /*
            int list_num = Dart_query_tasklist_num();
            CHECK(list_num >= 1);

            int task_num = Dart_query_task_num(1);
            CHECK(task_num >= 1);

            int list_id = Dart_query_tasklist_id(0);
            CHECK(list_id > 0);

            char* list_name = Dart_query_tasklist_name(list_id);
            CHECK(list_name != nullptr);
            CHECK(strlen(list_name) > 0);
            */
        }

        SUBCASE("Test Dart_update_task") {
            // 创建测试数据
            Dart_create_tasklist("Update Test List");
            Dart_create_task(1, "Original Task", "Original Description",
                           "2024-01-01 10:00:00", "2024-01-01 11:00:00", 1);

            int result = Dart_update_task(1, 1, "Updated Task", "Updated Description",
                                        "2024-01-02 10:00:00", "2024-01-02 11:00:00", 2);
            CHECK(result == 0);
        }

        SUBCASE("Test Dart_update_task_stat") {
            // 创建测试数据
            Dart_create_tasklist("Status Test List");
            Dart_create_task(1, "Status Task", "Description",
                           "2024-01-01 10:00:00", "2024-01-01 11:00:00", 1);

            int result = Dart_update_task_stat(1, 1, 3);
            CHECK(result == 0);
        }

        SUBCASE("Test Dart_move_task") {
            // 创建两个列表
            Dart_create_tasklist("Source List");
            Dart_create_tasklist("Target List");
            Dart_create_task(1, "Move Task", "Description",
                           "2024-01-01 10:00:00", "2024-01-01 11:00:00", 1);

            int result = Dart_move_task(1, 1, 2);
            CHECK(result == 0);
        }

        SUBCASE("Test Dart delete operations") {
            // 创建测试数据
            Dart_create_tasklist("Delete Test List");
            Dart_create_task(1, "Delete Task", "Description",
                           "2024-01-01 10:00:00", "2024-01-01 11:00:00", 1);

            // 删除任务
            int result = Dart_delete_task(1);
            CHECK(result == 0);

            // 删除列表
            result = Dart_delete_tasklist(1);
            CHECK(result == 0);
        }
    }
}

// 原有的Dart API测试保持不变
TEST_SUITE("Dart API Test") {
    TEST_CASE("Dart Api Test") {

        {
            remove("tasks.db");
            Database db("tasks.db");

            Database::TaskList *list;
            db.new_task_list(list);
            fill_list(list);
            db.add_task_list(list);
            db.new_task_list(list);
            fill_list(list);
            db.add_task_list(list);
            db.new_task_list(list);
            fill_list(list);
            db.add_task_list(list);

            Database::Task *task;
            db.new_task(task);
            fill_task(task);
            db.add_task(task);
            db.new_task(task);
            fill_task(task);
            task->belong = 2;
            db.add_task(task);

        }

        Dart_exit();
        Dart_init();
        auto list_num = Dart_get_list_pre();
        auto task_num = Dart_get_task_pre();

        REQUIRE(list_num == 3);
        REQUIRE(task_num == 2);

        vector<Dart_TaskList> lists;
        lists.reserve(list_num);
        for (int i = 0; i < list_num; i++) {
            lists.emplace_back(Dart_get_list());
        }

        vector<Dart_Task> tasks;
        tasks.reserve(task_num);
        for (int i = 0; i < task_num; i++) {
            tasks.emplace_back(Dart_get_task());
        }

        CHECK(string(lists[0].title) == "Test List");
        CHECK(string(lists[1].title) == "Test List");
        CHECK(string(tasks[0].title) == "Test Task");
        CHECK(string(tasks[1].title) == "Test Task");
        CHECK(tasks[0].list_id + tasks[1].list_id == 3);
        CHECK(string(tasks[0].description) == "Test description.");
        CHECK(string(tasks[1].description) == "Test description.");
        // CHECK(string(tasks[0].startDate) == "1970-01-01 08:00:00");
        // CHECK(string(tasks[1].startDate) == "1970-01-01 08:00:00");
        // CHECK(string(tasks[0].endDate) == "1970-01-01 08:16:40");
        // CHECK(string(tasks[1].endDate) == "1970-01-01 08:16:40");
        CHECK(tasks[0].status == 1);
        CHECK(tasks[1].status == 1);
    }
}

// UUID生成器测试
TEST_SUITE("UUID Generator Test") {
    TEST_CASE("UUID Generation Test") {
        SUBCASE("Test UUID uniqueness") {
            string uuid1 = UUIDGenerator::generate();
            string uuid2 = UUIDGenerator::generate();

            CHECK_FALSE(uuid1.empty());
            CHECK_FALSE(uuid2.empty());
            CHECK(uuid1 != uuid2);
        }

        SUBCASE("Test UUID format") {
            string uuid = UUIDGenerator::generate();
            // UUID应该是36个字符（包含连字符）
            CHECK(uuid.length() == 36);
            // 检查连字符位置
            CHECK(uuid[8] == '-');
            CHECK(uuid[13] == '-');
            CHECK(uuid[18] == '-');
            CHECK(uuid[23] == '-');
        }

        SUBCASE("Test multiple UUID generation") {
            std::set<string> uuids;
            const int num_uuids = 1000;

            for (int i = 0; i < num_uuids; i++) {
                string uuid = UUIDGenerator::generate();
                CHECK(uuids.find(uuid) == uuids.end()); // 确保唯一性
                uuids.insert(uuid);
            }

            CHECK(uuids.size() == num_uuids);
        }
    }
}