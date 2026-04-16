#!/usr/bin/env bash

UI_BOX_W=88
UI_BOX_H=22
UI_START_COL=0
UI_START_ROW=0
UI_BASE_BOX_W=88
UI_BASE_BOX_H=22
UI_MIN_BOX_W=56
UI_MIN_BOX_H=14
UI_MAX_BOX_W=116
UI_MAX_BOX_H=30
UI_PAGE_LINE_LIMIT=16

UI_C_RESET=""
UI_C_BORDER=""
UI_C_TITLE=""
UI_C_PROMPT=""
UI_C_TEXT=""
UI_C_HELP=""
UI_C_OPT_NORMAL=""
UI_C_FOCUS=""

ui_require_tty() {
   if [[ ! -t 0 || ! -t 1 ]]; then
      echo "ERROR: admin-tools requiere una terminal interactiva (TTY)."
      exit 1
   fi
}

ui_init_theme() {
   UI_C_RESET="$(tput sgr0 2>/dev/null || true)"
   UI_C_BORDER="$(tput setaf 6 2>/dev/null || true)"
   UI_C_TITLE="$(tput bold 2>/dev/null || true)$(tput setaf 3 2>/dev/null || true)"
   UI_C_PROMPT="$(tput bold 2>/dev/null || true)$(tput setaf 7 2>/dev/null || true)"
   UI_C_TEXT="$(tput setaf 7 2>/dev/null || true)"
   UI_C_HELP="$(tput setaf 2 2>/dev/null || true)"
   UI_C_OPT_NORMAL="$(tput setaf 7 2>/dev/null || true)"
   UI_C_FOCUS="$(tput bold 2>/dev/null || true)$(tput rev 2>/dev/null || true)"
}

ui_setup_terminal() {
   stty -echo -icanon min 1 time 0
   tput civis > /dev/tty 2>/dev/null || true
}

ui_restore_terminal() {
   stty sane 2>/dev/null || true
   tput sgr0 > /dev/tty 2>/dev/null || true
   tput cnorm > /dev/tty 2>/dev/null || true
}

ui_cleanup() {
   ui_restore_terminal
   clear
}

ui_calc_layout() {
   local target_w="${1:-$UI_BASE_BOX_W}"
   local target_h="${2:-$UI_BASE_BOX_H}"
   local cols lines

   cols="$(tput cols)"
   lines="$(tput lines)"

   UI_BOX_W="$target_w"
   UI_BOX_H="$target_h"

   (( UI_BOX_W > cols - 2 )) && UI_BOX_W=$((cols - 2))
   (( UI_BOX_H > lines - 2 )) && UI_BOX_H=$((lines - 2))
   (( UI_BOX_W < UI_MIN_BOX_W )) && UI_BOX_W=$UI_MIN_BOX_W
   (( UI_BOX_H < UI_MIN_BOX_H )) && UI_BOX_H=$UI_MIN_BOX_H

   UI_START_COL=$(((cols - UI_BOX_W) / 2))
   UI_START_ROW=$(((lines - UI_BOX_H) / 2))
}

ui_draw_box_line() {
   local row="$1"
   local col="$2"
   local width="$3"

   tput cup "$row" "$col"
   printf "%s+" "$UI_C_BORDER"
   printf '%*s' $((width - 2)) '' | tr ' ' '-'
   printf "+%s" "$UI_C_RESET"
}

ui_draw_frame() {
   local i

   ui_draw_box_line "$UI_START_ROW" "$UI_START_COL" "$UI_BOX_W"
   for ((i = 1; i < UI_BOX_H - 1; i++)); do
      tput cup $((UI_START_ROW + i)) "$UI_START_COL"
      printf "%s|%s" "$UI_C_BORDER" "$UI_C_RESET"
      tput cup $((UI_START_ROW + i)) $((UI_START_COL + UI_BOX_W - 1))
      printf "%s|%s" "$UI_C_BORDER" "$UI_C_RESET"
   done
   ui_draw_box_line $((UI_START_ROW + UI_BOX_H - 1)) "$UI_START_COL" "$UI_BOX_W"
}

ui_get_key_raw() {
   local key rest tail read_status

   IFS= read -rsn1 key
   read_status=$?
   if [[ $read_status -ne 0 ]]; then
      echo "OTHER"
      return 0
   fi

   if [[ -z "${key:-}" ]]; then
      echo "ENTER"
      return 0
   fi

   if [[ "$key" == $'\x1b' ]]; then
      IFS= read -rsn2 rest || true
      case "${rest:-}" in
         "[A") echo "UP" ;;
         "[B") echo "DOWN" ;;
         "[C") echo "RIGHT" ;;
         "[D") echo "LEFT" ;;
         "[5") IFS= read -rsn1 tail || true; [[ "${tail:-}" == "~" ]] && echo "PGUP" || echo "ESC" ;;
         "[6") IFS= read -rsn1 tail || true; [[ "${tail:-}" == "~" ]] && echo "PGDN" || echo "ESC" ;;
         *) echo "ESC" ;;
      esac
      return 0
   fi

   case "$key" in
      $'\t') echo "TAB" ;;
      $'\n'|$'\r') echo "ENTER" ;;
      q|Q) echo "QUIT" ;;
      [0-9]) echo "DIGIT:$key" ;;
      *) echo "OTHER" ;;
   esac
}

ui_draw_menu() {
   local title="$1"
   local prompt="$2"
   local options_name="$3"
   local selected="$4"
   local help_text="$5"
   local show_numbers="$6"
   local -n options_ref="$options_name"
   local row i label

   ui_calc_layout
   clear
   ui_draw_frame

   tput cup $((UI_START_ROW + 1)) $((UI_START_COL + 2))
   printf "%s%s%s" "$UI_C_TITLE" "$title" "$UI_C_RESET"

   tput cup $((UI_START_ROW + 3)) $((UI_START_COL + 2))
   printf "%s%s%s" "$UI_C_PROMPT" "$prompt" "$UI_C_RESET"

   for i in "${!options_ref[@]}"; do
      row=$((UI_START_ROW + 5 + i))
      tput cup "$row" $((UI_START_COL + 4))
      if [[ "$show_numbers" -eq 1 ]]; then
         label="$((i + 1)). ${options_ref[$i]}"
      else
         label="${options_ref[$i]}"
      fi

      if [[ "$i" -eq "$selected" ]]; then
         printf "%s %-72.72s %s" "$UI_C_FOCUS" "$label" "$UI_C_RESET"
      else
         printf "%s %-72.72s %s" "$UI_C_OPT_NORMAL" "$label" "$UI_C_RESET"
      fi
   done

   tput cup $((UI_START_ROW + UI_BOX_H - 2)) $((UI_START_COL + 2))
   printf "%s%s%s" "$UI_C_HELP" "$help_text" "$UI_C_RESET"
}

ui_run_menu() {
   local title="$1"
   local prompt="$2"
   local options_name="$3"
   local help_text="$4"
   local show_numbers="${5:-1}"
   local default_selected="${6:-0}"
   local -n options_ref="$options_name"
   local selected="$default_selected"
   local key digit idx

   UI_MENU_EVENT=""
   UI_MENU_SELECTED=0

   while true; do
      ui_draw_menu "$title" "$prompt" "$options_name" "$selected" "$help_text" "$show_numbers"
      key="$(ui_get_key_raw)"

      if [[ "$key" == DIGIT:* ]]; then
         digit="${key#DIGIT:}"
         idx=$((digit - 1))
         if (( idx >= 0 && idx < ${#options_ref[@]} )); then
            UI_MENU_EVENT="SELECT"
            UI_MENU_SELECTED="$idx"
            return 0
         fi
         key="OTHER"
      fi

      case "$key" in
         UP)
            if (( selected > 0 )); then
               selected=$((selected - 1))
            else
               selected=$((${#options_ref[@]} - 1))
            fi
            ;;
         DOWN)
            if (( selected < ${#options_ref[@]} - 1 )); then
               selected=$((selected + 1))
            else
               selected=0
            fi
            ;;
         ENTER)
            UI_MENU_EVENT="SELECT"
            UI_MENU_SELECTED="$selected"
            return 0
            ;;
         ESC|QUIT)
            UI_MENU_EVENT="QUIT"
            return 0
            ;;
      esac
   done
}

ui_show_text_box() {
   local title="$1"
   local lines_name="$2"
   local footer="${3:-ENTER/Esc/q: volver}"
   local -n lines_ref="$lines_name"
   local total_lines start end count offset max_offset jump_size
   local key view_footer max_len line content_width max_lines i row
   local h_offset max_h_offset
   local view_lines=()

   total_lines=${#lines_ref[@]}
   (( total_lines == 0 )) && lines_ref=("Sin contenido.") && total_lines=1
   offset=0
   h_offset=0
   max_offset=$((total_lines - UI_PAGE_LINE_LIMIT))
   (( max_offset < 0 )) && max_offset=0
   jump_size=$((UI_PAGE_LINE_LIMIT - 2))
   (( jump_size < 1 )) && jump_size=1

   while true; do
      start=$offset
      end=$((start + UI_PAGE_LINE_LIMIT))
      (( end > total_lines )) && end=$total_lines
      count=$((end - start))
      view_lines=("${lines_ref[@]:start:count}")

      max_len=0
      for line in "${view_lines[@]}"; do
         (( ${#line} > max_len )) && max_len=${#line}
      done
      (( ${#title} > max_len )) && max_len=${#title}
      (( ${#footer} > max_len )) && max_len=${#footer}

      ui_calc_layout $((max_len + 6)) $((count + 6))
      (( UI_BOX_W > UI_MAX_BOX_W )) && UI_BOX_W=$UI_MAX_BOX_W
      (( UI_BOX_H > UI_MAX_BOX_H )) && UI_BOX_H=$UI_MAX_BOX_H
      ui_calc_layout "$UI_BOX_W" "$UI_BOX_H"

      clear
      ui_draw_frame
      tput cup $((UI_START_ROW + 1)) $((UI_START_COL + 2))
      printf "%s%s%s" "$UI_C_TITLE" "$title" "$UI_C_RESET"

      content_width=$((UI_BOX_W - 4))
      max_h_offset=$((max_len - content_width))
      (( max_h_offset < 0 )) && max_h_offset=0
      (( h_offset > max_h_offset )) && h_offset=$max_h_offset
      max_lines=$((UI_BOX_H - 6))
      for ((i = 0; i < ${#view_lines[@]} && i < max_lines; i++)); do
         row=$((UI_START_ROW + 3 + i))
         tput cup "$row" $((UI_START_COL + 2))
         line="${view_lines[$i]}"
         if (( h_offset > 0 )); then
            line="${line:$h_offset}"
         fi
         printf "%s%-*.*s%s" "$UI_C_TEXT" "$content_width" "$content_width" "$line" "$UI_C_RESET"
      done

      if (( total_lines > UI_PAGE_LINE_LIMIT )); then
         view_footer="${footer} | Up/Down/PgUp/PgDn: scroll (${start+1}-${end}/${total_lines})"
      else
         view_footer="$footer"
      fi
      if (( max_h_offset > 0 )); then
         view_footer="${view_footer} | Left/Right: horiz (${h_offset}/${max_h_offset})"
      fi
      tput cup $((UI_START_ROW + UI_BOX_H - 2)) $((UI_START_COL + 2))
      printf "%s%-*.*s%s" "$UI_C_HELP" "$content_width" "$content_width" "$view_footer" "$UI_C_RESET"

      key="$(ui_get_key_raw)"
      case "$key" in
         UP) (( offset > 0 )) && offset=$((offset - 1)) ;;
         DOWN) (( offset < max_offset )) && offset=$((offset + 1)) ;;
         LEFT) (( h_offset > 0 )) && h_offset=$((h_offset - 1)) ;;
         RIGHT) (( h_offset < max_h_offset )) && h_offset=$((h_offset + 1)) ;;
         PGUP)
            if (( offset > 0 )); then
               offset=$((offset - jump_size))
               (( offset < 0 )) && offset=0
            fi
            ;;
         PGDN)
            if (( offset < max_offset )); then
               offset=$((offset + jump_size))
               (( offset > max_offset )) && offset=$max_offset
            fi
            ;;
         ENTER|ESC|QUIT) return 0 ;;
      esac
   done
}

ui_show_message() {
   local title="$1"
   local message="$2"
   local rendered_message=""
   local lines=()
   printf -v rendered_message '%b' "$message"
   mapfile -t lines <<< "$rendered_message"
   ui_show_text_box "$title" lines
}

ui_prompt_input() {
   local prompt="$1"
   local default_value="${2:-}"
   local answer=""

   ui_restore_terminal
   clear > /dev/tty
   printf "\n%s\n" "$prompt" > /dev/tty
   if [[ -n "$default_value" ]]; then
      printf "Valor [%s]: " "$default_value" > /dev/tty
   else
      printf "Valor: " > /dev/tty
   fi
   read -r answer < /dev/tty
   ui_setup_terminal

   if [[ -z "$answer" ]]; then
      answer="$default_value"
   fi

   printf '%s\n' "$answer"
}
