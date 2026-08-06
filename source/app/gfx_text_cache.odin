package app

import "../platform"
import "core:c"
import "core:fmt"
import sdl "vendor:sdl3"
import "vendor:sdl3/ttf"

Text_Key :: distinct u64

TEXT_CACHE_MAX :: 256
// Num frames an untouched entry survives before termination
TEXT_CACHE_TTL_FRAMES :: 120

Text_Cache_Entry :: struct {
	key:        Text_Key,
	text:       ^ttf.Text,
	last_frame: u64,
}

Text_Cache :: struct {
	entries:     [TEXT_CACHE_MAX]Text_Cache_Entry,
	entry_count: int,
	frame:       u64,
	dropped:     int,
}

// FNV-1a over bytes mixed with style id. Hash-only key: collision draws the wrong cached string
// which at a few hundred live strings is around 1e-14. Store & compare string if caching doc text.
@(require_results)
text_key :: proc "contextless" (str: string, style: Text) -> Text_Key {
	FNV_OFFSET :: u64(14695981039346656037)
	FNV_PRIME :: u64(1099511628211)

	h := FNV_OFFSET
	for b in transmute([]u8)str {
		h = (h ~ u64(b)) * FNV_PRIME
	}
	return Text_Key((h ~ u64(style)) * FNV_PRIME)
}

// Returns retained ttf.Text
@(require_results)
text_cache_get :: proc(
	cache: ^Text_Cache,
	device: ^platform.Device,
	asts: ^Assets,
	str: string,
	style: Text,
) -> ^ttf.Text {
	key := text_key(str, style)

	// Linear scan works; revisit if TEXT_CACHE_MAX grows past ~1k
	for &e in cache.entries[:cache.entry_count] {
		if e.key != key do continue
		e.last_frame = cache.frame
		return e.text
	}

	font := asts.fonts[style]
	text := ttf.CreateText(device.text_engine, font, cstring(raw_data(str)), c.size_t(len(str)))
	if text == nil {
		fmt.eprintfln("[text] CreatedText failed: %s", sdl.GetError())
		return nil
	}
	// SDL_ttf strips trailing spaces off every line by default, stalling a caret.
	if !ttf.SetTextWrapWhitespaceVisible(text, true) {
		fmt.eprintfln("[text] SetTextWrapWhitespaceVisible failed: %s", sdl.GetError())
	}

	if cache.entry_count == TEXT_CACHE_MAX {
		cache.dropped += 1

		coldest := 0
		for e, i in cache.entries {
			if e.last_frame < cache.entries[coldest].last_frame do coldest = i
		}
		ttf.DestroyText(cache.entries[coldest].text)
		cache.entries[coldest] = {
			key        = key,
			text       = text,
			last_frame = cache.frame,
		}
		return text
	}

	cache.entries[cache.entry_count] = {
		key        = key,
		text       = text,
		last_frame = cache.frame,
	}
	cache.entry_count += 1
	return text
}

// Advance cache clock, evict entries untouched for TEXT_CACHE_TTL_FRAMES
text_cache_frame_end :: proc(cache: ^Text_Cache) {
	cache.frame += 1

	i := 0
	for i < cache.entry_count {
		e := cache.entries[i]
		if cache.frame - e.last_frame <= TEXT_CACHE_TTL_FRAMES {
			i += 1
			continue
		}
		ttf.DestroyText(e.text)
		cache.entry_count -= 1
		cache.entries[i] = cache.entries[cache.entry_count]
	}
}

text_cache_clear :: proc(cache: ^Text_Cache) {
	for e in cache.entries[:cache.entry_count] do ttf.DestroyText(e.text)
	cache^ = {}
}
