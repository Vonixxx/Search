package search

import      "core:c"
import      "core:os"
import      "core:fmt"
import      "core:sort"
import      "core:slice"
import      "base:runtime"
import str  "core:strings"
import ray  "vendor:raylib"
import      "core:unicode/utf8"
import path "core:path/filepath"

BUFFER_SIZE   :: 64
SCREEN_WIDTH  :: 320
SCREEN_HEIGHT :: 240

Position := struct {
	x: f32,
	y: f32,
} {
	x = 0,
	y = 0,
}

Size := struct {
	w: f32,
	h: f32,
} {
	w = 0,
	h = 0,
}

Textbox := struct {
	count         : int,
	edit_mode     : bool,
	buffer_size   : c.int,
	input_text    : cstring,
	input_builder : str.Builder,
	buffer        : [BUFFER_SIZE]u8,
} {
	edit_mode   = true,
	buffer_size = BUFFER_SIZE,
}

Fuzzy := struct {
	score     : int,
	max_score : int,
	words     : [dynamic]cstring,
} {
	max_score = 0,
}

List := struct {
	focus          : c.int,
	active         : c.int,
	size           : c.int,
	scroll_index   : c.int,

	env_vars_index : int,
	env_path_var   : string,
	env_vars       : []string,

	execs_fuzzied     : []cstring,
	execs_untrimmed   : []cstring,
	execs_searched    : [^]cstring,
	execs_sorted      : [dynamic]cstring,
	execs_trimmed     : [dynamic]cstring,
	execs_non_fuzzied : [dynamic]cstring,
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

	str.write_string(&Textbox.input_builder , string(Textbox.buffer[:Textbox.count]))

	return str.to_cstring(&Textbox.input_builder)	
}

fuzzy :: proc(input: cstring, dictionary: ^[dynamic]cstring, results: int) -> []cstring {
	scores := make(map[int][dynamic]cstring)
	defer delete(scores)

	for word in dictionary {
		Fuzzy.score = str.levenshtein_distance(string(input),string(word))

		if Fuzzy.score in scores {
			append(&scores[Fuzzy.score], word)
		} else {
			scores[Fuzzy.score] = make([dynamic]cstring)
			append(&scores[Fuzzy.score], word)
			Fuzzy.max_score = max(Fuzzy.max_score, Fuzzy.score)
		}
	}

	top := make([dynamic]cstring)

	for i in 0..=Fuzzy.max_score {
		if i in scores == false do continue

		Fuzzy.words = scores[i]
		slice.sort(Fuzzy.words[:])
		append(&top,..Fuzzy.words[:])

		if results != -1 && len(top) > results {
			break
		}
	}

	if results == -1 || results > len(top) do return top[:]
	return top[:results]
}

trimmer :: proc() -> [dynamic]cstring {
	#no_bounds_check env : [^]cstring = &runtime.args__[len(runtime.args__) + 1]

	for List.env_vars_index = 0; env[List.env_vars_index] != nil; List.env_vars_index += 1 {
		List.env_vars = make([]string, List.env_vars_index)

		for &var,index in List.env_vars {
			var = string(env[index])
			if str.contains(var,"PATH=") do List.env_path_var = var
		}
	}

	for execs_dir in str.split_iterator(&List.env_path_var, ":") {
		List.execs_dir       = ray.LoadDirectoryFiles(str.clone_to_cstring(execs_dir))
		List.execs_untrimmed = List.execs_dir.paths[:List.execs_dir.count]

		for &exec in List.execs_untrimmed {
			exec = str.clone_to_cstring(path.base(string(exec)))

			append(&List.execs_trimmed, exec)
		}
	}

	sort.quick_sort(List.execs_trimmed[:])
	List.execs_sorted = slice.clone_to_dynamic(slice.unique(List.execs_trimmed[:]))

	return List.execs_sorted
}

main :: proc() {
	ray.InitWindow(SCREEN_WIDTH , SCREEN_HEIGHT , "Search")
	defer ray.CloseWindow()

	ray.SetTargetFPS(60)

	ray.GuiLoadStyle("./Source/mocha.rgs")

	ray.ClearBackground(ray.Color{17, 17, 27,255})

	Textbox.input_text = input()

	List.execs_non_fuzzied = trimmer()
	defer delete(List.execs_non_fuzzied)

	for !ray.WindowShouldClose() {
		ray.BeginDrawing()
		defer ray.EndDrawing()

		List.execs_fuzzied = fuzzy(Textbox.input_text,&List.execs_non_fuzzied,int(List.size))
		defer delete(List.execs_fuzzied)

		List.execs_searched = raw_data(List.execs_fuzzied)

		Size.h = 30
		Size.w = 40

		Position.y = 10
		Position.x = (SCREEN_WIDTH - Size.w) / 2

		ray.GuiLabel(ray.Rectangle{Position.x,Position.y,Size.w,Size.h} , "Search")

		Size.h = 20
		Size.w = 100

		Position.y = 35
		Position.x = (SCREEN_WIDTH - Size.w) / 2

		ray.GuiTextBox(ray.Rectangle{Position.x,Position.y,Size.w,Size.h} , Textbox.input_text , Textbox.buffer_size , Textbox.edit_mode)

		Size.h = 155
		Size.w = 130

		Position.y = 70
		Position.x = (SCREEN_WIDTH - Size.w) / 2

		ray.GuiListViewEx(ray.Rectangle{Position.x,Position.y,Size.w,Size.h} , List.execs_searched , List.size , &List.scroll_index , &List.active , &List.focus)

		if !ray.IsKeyDown(.RIGHT_SHIFT) && ray.IsKeyPressed(.TAB) {
			List.active += 1

			if List.active == 5 do List.active = 0
		}

		if ray.IsKeyDown(.RIGHT_SHIFT) && ray.IsKeyPressed(.TAB) {
			List.active -= 1

			if List.active < 0 do List.active = 4
		}

		if ray.IsKeyPressed(.ENTER) || ray.IsMouseButtonPressed(.LEFT) {
			command_path : string = string(List.execs_searched[List.active])

			os.execvp(command_path , nil)
		}
	}
}
