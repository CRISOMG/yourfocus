import { JORNADAS, type BloqueJornada } from "~~/shared/utils/v2/jornada";

export enum TimeMeasurementMode {
  POMODORO = "pomodoro",
  FLOW = "flow",
}

// Re-export from existing pomodoro domain for shared use
export { PomodoroState as TimeMeasurementState } from "./pomodoro-domain";

/**
 * Determines which jornada block the given time falls into.
 * Uses the JORNADAS from shared/utils/v2/jornada.ts
 */
export function getCurrentJornadaBlock(
  now: Date = new Date(),
  timeZone: string = "America/Caracas",
): BloqueJornada {
  const tzDate = new Date(now.toLocaleString("en-US", { timeZone }));
  const hour = tzDate.getHours();
  const minute = tzDate.getMinutes();
  const currentTotalMinutes = hour * 60 + minute;

  const bloque = JORNADAS.find((j) => {
    const inicioTotal = j.inicioHora * 60 + j.inicioMinuto;
    const finTotal = j.finHora * 60 + j.finMinuto;

    if (inicioTotal <= finTotal) {
      return (
        currentTotalMinutes >= inicioTotal && currentTotalMinutes < finTotal
      );
    } else {
      // Bloque nocturno que cruza medianoche (e.g. 22:00 a 02:00)
      return (
        currentTotalMinutes >= inicioTotal || currentTotalMinutes < finTotal
      );
    }
  });

  return bloque || JORNADAS[0]!;
}

/**
 * Calculates the ISO timestamp when a jornada block ends.
 * If targetBlock is provided, uses that block instead of the current one.
 */
export function getJornadaLimitTimestamp(
  now: Date = new Date(),
  timeZone: string = "America/Caracas",
  targetBlock?: BloqueJornada,
): string {
  const bloque = targetBlock || getCurrentJornadaBlock(now, timeZone);

  // Build the limit date at the end of the target block
  const tzDate = new Date(now.toLocaleString("en-US", { timeZone }));
  const limitDate = new Date(tzDate);

  limitDate.setHours(bloque.finHora, bloque.finMinuto, 0, 0);

  // If the limit is before now (crosses midnight or past block), add a day
  if (limitDate.getTime() <= tzDate.getTime()) {
    limitDate.setDate(limitDate.getDate() + 1);
  }

  return limitDate.toISOString();
}

/**
 * Formats seconds into a progressive clock display (HH:MM:SS or MM:SS)
 */
export function formatElapsedTime(totalSeconds: number): string {
  const hours = Math.floor(totalSeconds / 3600);
  const minutes = Math.floor((totalSeconds % 3600) / 60);
  const seconds = totalSeconds % 60;

  const pad = (n: number) => n.toString().padStart(2, "0");

  if (hours > 0) {
    return `${pad(hours)}:${pad(minutes)}:${pad(seconds)}`;
  }
  return `${pad(minutes)}:${pad(seconds)}`;
}

/**
 * Gets a user-friendly description of the current jornada
 * e.g. "Vespertina temprana · hasta 16:00"
 */
export function getJornadaDisplayInfo(
  now: Date = new Date(),
  timeZone: string = "America/Caracas",
): { nombre: string; descripcion: string; limitLabel: string } {
  const bloque = getCurrentJornadaBlock(now, timeZone);
  const pad = (n: number) => n.toString().padStart(2, "0");
  const limitLabel = `hasta ${pad(bloque.finHora)}:${pad(bloque.finMinuto)}`;

  const nombreCap =
    bloque.nombre.charAt(0).toUpperCase() + bloque.nombre.slice(1);

  return {
    nombre: nombreCap,
    descripcion: bloque.descripcion,
    limitLabel,
  };
}

export type JornadaOption = {
  label: string;
  value: string; // nombre del bloque
  limitLabel: string;
  bloque: BloqueJornada;
};

/**
 * Returns jornada blocks from the current one onward (within the same day).
 * Each option includes the block name, its end time label, and the block data.
 * Used to populate the jornada limit selector in the Flow UI.
 */
export function getRemainingJornadaOptions(
  now: Date = new Date(),
  timeZone: string = "America/Caracas",
): JornadaOption[] {
  const currentBlock = getCurrentJornadaBlock(now, timeZone);
  const pad = (n: number) => n.toString().padStart(2, "0");

  // Find the index of the current block
  const currentIndex = JORNADAS.findIndex(
    (j) => j.nombre === currentBlock.nombre,
  );

  // Get blocks from current onward, excluding sleep blocks
  const remaining: JornadaOption[] = [];
  for (let i = currentIndex; i < JORNADAS.length; i++) {
    const j = JORNADAS[i]!;
    // Stop at sleep blocks (descanso)
    if (j.tipo === "descanso") break;

    const nombreCap = j.nombre.charAt(0).toUpperCase() + j.nombre.slice(1);
    const limitLabel = `${pad(j.finHora)}:${pad(j.finMinuto)}`;

    remaining.push({
      label: `${nombreCap} — hasta ${limitLabel}`,
      value: j.nombre,
      limitLabel,
      bloque: j,
    });
  }

  return remaining;
}
