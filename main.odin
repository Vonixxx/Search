package search

import     "core:sort"
import     "core:c"
import     "core:os"
import     "core:fmt"
import path "core:path/filepath"
import     "core:slice"
import     "core:strings"
import     "base:runtime"
import ray "vendor:raylib"
import     "core:unicode/utf8"

SCREEN_WIDTH  :: 320
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
	focus        : c.int,
	active       : c.int,
	size         : c.int,
	scroll_index : c.int,

	execs_fuzzied     : []cstring,
	execs_untrimmed   : []cstring,
	execs_searched    : [^]cstring,
	execs_non_fuzzied : [dynamic]cstring,
	execs_trimmed     : [dynamic]cstring,
	execs_dir         : ray.FilePathList,
} {
	size          = 5,
	execs_trimmed = make([dynamic]cstring),
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

fuzzy :: proc(input: cstring, dictionary: ^[dynamic]cstring, results: int) -> []cstring {
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
	#no_bounds_check env : [^]cstring = &runtime.args__[len(runtime.args__) + 1]
	path_var             : string     = string(env[162])

	for execs_dir in strings.split_iterator(&path_var, ":") {
		List.execs_dir            = ray.LoadDirectoryFiles(strings.clone_to_cstring(execs_dir))
		List.execs_untrimmed = List.execs_dir.paths[:List.execs_dir.count]

		for &exec in List.execs_untrimmed {
			exec = strings.clone_to_cstring(path.base(string(exec)))

			append(&List.execs_trimmed, exec)
		}
	}

	sort.quick_sort(List.execs_trimmed[:])
	execs_sorted := slice.clone_to_dynamic(slice.unique(List.execs_trimmed[:]))

	return execs_sorted
}

main :: proc() {
	ray.InitWindow(SCREEN_WIDTH , SCREEN_HEIGHT , "Search")
	defer ray.CloseWindow()

	ray.SetTargetFPS(60)

	Textbox.input_text = input()

	List.execs_non_fuzzied = trimmer()
	defer delete(List.execs_non_fuzzied)

	for !ray.WindowShouldClose() {
		ray.BeginDrawing()
		defer ray.EndDrawing()

		ray.ClearBackground(ray.RAYWHITE)

		List.execs_fuzzied = fuzzy(Textbox.input_text,&List.execs_non_fuzzied,int(List.size))
		defer delete(List.execs_fuzzied)

		List.execs_searched = raw_data(List.execs_fuzzied)

		ray.GuiLabel(ray.Rectangle{140,10,40,30} , "Search")

		ray.GuiTextBox(ray.Rectangle{110,35,100,20} , Textbox.input_text , Textbox.buffer_size , true)

		ray.GuiListViewEx(ray.Rectangle{92,70,130,155} , List.execs_searched , List.size , &List.scroll_index , &List.active , &List.focus)

		if !ray.IsKeyDown(ray.KeyboardKey.RIGHT_SHIFT) && ray.IsKeyPressed(ray.KeyboardKey.TAB) {
			List.active       += 1

			if List.active == 5 do List.active = 0
		}

		if ray.IsKeyDown(ray.KeyboardKey.RIGHT_SHIFT) && ray.IsKeyPressed(ray.KeyboardKey.TAB) {
			List.active       -= 1

			if List.active < 0 do List.active = 4
		}

		if ray.IsKeyPressed(ray.KeyboardKey.ENTER) {
			command_path : string = string(List.execs_searched[List.active])

			os.execvp(command_path , nil)
		}
	}
}

