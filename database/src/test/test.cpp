//
// Created by kibi on 24-12-7.
//
#define DOCTEST_CONFIG_IMPLEMENT_WITH_MAIN
#include "doctest.h"
#include "../database.h"

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

// TODO: Test Database Error

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