import type { Database } from "~/types/database.types";

export type Pomodoro = Database["public"]["Tables"]["pomodoros"];
export type PomodoroCycle = Database["public"]["Tables"]["pomodoros_cycles"];
export type PomodoroTagged = Database["public"]["Tables"]["pomodoros_tags"];
export type Tag = Database["public"]["Tables"]["tags"];
