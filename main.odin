package search

import     "core:c"
import     "core:os"
import     "core:fmt"
import     "core:slice"
import     "core:strings"
import     "base:runtime"
import ray "vendor:raylib"
import     "core:unicode/utf8"

SCREEN_WIDTH  :: 480
SCREEN_HEIGHT :: 240

Textbox := struct {
	count         : int,
	buffer_size   : c.int,
	input_text    : cstring,
	buffer        : [256]u8,
	input_builder : strings.Builder,
} {
	buffer_size = 64,
}

List := struct {
	focus              : c.int,
	active             : c.int,
	list_size          : c.int,
	scroll_index       : c.int,
	dirs               : []string,
	exec_names         : []cstring,
	execs_fuzzied      : [^]cstring,
	exec_names_trimmed : ^[]cstring,
	execs_dir          : ray.FilePathList,
} {
	list_size = 10,
	dirs      = {"/run/current-system/sw/bin/","/home/Luca/.nix-profile/bin/"},
}

input :: proc() -> cstring {
	for Textbox.count < len(Textbox.buffer) {
		char := ray.GetCharPressed()

		if char == 0 do break

		byte, width   := utf8.encode_rune(char)
		Textbox.count += copy(Textbox.buffer[Textbox.count:] , byte[:width])
	}

	strings.write_string(&Textbox.input_builder , string(Textbox.buffer[:Textbox.count]))

	return strings.to_cstring(&Textbox.input_builder)	
}

fuzzy :: proc(input: cstring, dictionary: ^[dynamic]cstring, results: int = 100) -> []cstring {
	scores := make(map[int][dynamic]cstring)
	defer delete(scores)

	max_score := 0

	for word in dictionary {
		score := strings.levenshtein_distance(string(input), string(word))

		if score in scores {
			append(&scores[score], word)
		} else {
			scores[score] = make([dynamic]cstring)
			append(&scores[score], word)
			max_score = max(max_score, score)
		}
	}

	top := make([dynamic]cstring)

	for i in 0..=max_score {
		if i in scores == false do continue

		words := scores[i]
		slice.sort(words[:])
		append(&top,..words[:])

		if results != -1 && len(top) > results {
			break
		}
	}

	if results == -1 || results > len(top) do return top[:]
	return top[:results]
}

trimmer :: proc() -> [dynamic]cstring {
	file_list : [dynamic]cstring = make([dynamic]cstring)

	for &dir in List.dirs {
		List.execs_dir  = ray.LoadDirectoryFiles(strings.clone_to_cstring(strings.trim_suffix((dir),"/")))
		List.exec_names = List.execs_dir.paths[:List.execs_dir.count]

		for &exec_name in List.exec_names {
			exec_name = strings.clone_to_cstring(strings.trim_prefix(string(exec_name), dir))
	
			append(&file_list, exec_name)
		}
	}

	return file_list
}

main :: proc() {
	ray.InitWindow(SCREEN_WIDTH , SCREEN_HEIGHT , "Search")
	defer ray.CloseWindow()

	ray.SetTargetFPS(60)

	Textbox.input_text = input()

	exec_names_trimmed : [dynamic]cstring

	exec_names_trimmed = trimmer()

	defer delete(exec_names_trimmed)

	for !ray.WindowShouldClose() {
		ray.BeginDrawing()
		defer ray.EndDrawing()

		ray.ClearBackground(ray.RAYWHITE)

		execs_list_fuzzied := fuzzy(Textbox.input_text,&exec_names_trimmed,10)
		defer delete(execs_list_fuzzied)

		List.execs_fuzzied = raw_data(execs_list_fuzzied)

		ray.GuiLabel(ray.Rectangle{300,80,40,30} , "Search")

		ray.GuiTextBox(ray.Rectangle{245,110,150,20} , Textbox.input_text , Textbox.buffer_size , true)

		if ray.IsKeyPressed(ray.KeyboardKey.TAB) {
			List.active       += 1
			List.scroll_index += 1
		}

		if ray.IsKeyPressed(ray.KeyboardKey.ENTER) {
			command_path : string = string(List.execs_fuzzied[List.active])

			os.execvp(command_path , nil)
		}

		ray.GuiListViewEx(ray.Rectangle{10,10,150,220} , List.execs_fuzzied , List.list_size , &List.scroll_index , &List.active , &List.focus)
	}
}

