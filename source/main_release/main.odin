package main

import app ".."
import "core:log"
import "core:mem"
import "core:os"
import "core:path/filepath"

_ :: mem

USE_TRACKING_ALLOCATOR :: #config(USE_TRACKING_ALLOCATOR, false)

main :: proc() {
	exec_path := os.args[0]
	exec_dir := filepath.dir(exec_path)
	os.set_working_directory(exec_dir)

	mode := os.Permissions{.Read_User, .Write_User, .Read_Group, .Read_Other}
	logh, logh_err := os.open("log.txt", {.Create, .Trunc, .Read, .Write}, mode)

	if logh_err == os.ERROR_NONE {
		os.stdout = logh
		os.stderr = logh
	}

	logger_alloc := context.allocator
	logger :=
		logh_err == os.ERROR_NONE ? log.create_file_logger(logh, allocator = logger_alloc) : log.create_console_logger(allocator = logger_alloc)
	context.logger = logger

	when USE_TRACKING_ALLOCATOR {
		default_allocator := context.allocator
		tracking_allocator := mem.Tracking_Allocator
		mem.tracking_allocator_init(&tracking_allocator, default_allocator)
		context.allocator = mem.tracking_allocator(&tracking_allocator)
	}

	app.app_init_window()
	app.app_init()

	for app.app_should_run() {
		app.app_update()
	}

	free_all(context.temp_allocator)
	app.app_shutdown()
	app.app_shutdown_window()

	when USE_TRACKING_ALLOCATOR {
		for _, value in tracking_allocator.allocator_map {
			log.errorf("%v: Leaked %v bytes\n", value.location, value.size)
		}

		mem.tracking_allocator_destroy(&tracking_allocator)
	}

	if logh_err == os.ERROR_NONE {
		log.destroy_file_logger(logger, logger_alloc)
	}
}

// make app use good GPU on laptops etc

@(export)
NvOptimusEnablement: u32 = 1

@(export)
AmdPowerXpressRequestHighPerformance: i32 = 1
