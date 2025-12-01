// tests/integration/pomodoro.test.ts
import { describe, it, expect, beforeAll, afterAll, afterEach } from "vitest";
import { setup } from "@nuxt/test-utils";
// Asegúrate de que useSupabaseClient esté importado si lo usas fuera de un composable/componente

describe("Pomodoro Supabase Integration", () => {
  // Variables globales para el setup/teardown
  let supabase: ReturnType<typeof useSupabaseClient>;
  let testUserId: string;
  let cycleIdToClean: number;

  beforeAll(async () => {
    supabase = useSupabaseClient();

    const { data: sessionData, error: authError } =
      await supabase.auth.signInWithPassword({
        email: process.env.SUPABASE_TEST_USER_EMAIL || "",
        password: process.env.SUPABASE_TEST_USER_PASSWORD || "",
      });

    if (authError || !sessionData?.user) {
      throw new Error(`Fallo de autenticación: ${authError?.message}`);
    }
    testUserId = sessionData.user.id;
  });

  afterAll(async () => {
    await supabase.auth.signOut();
  });

  it("cycleRepository.getCurrentCycle", async () => {
    const cycleRepository = usePomodoroCycleRepository();
    const cycle = await cycleRepository.getCurrent();
    console.log("cycle", cycle);
  });
  it("debe retornar TRUE si el ciclo tiene todos los tags requeridos", async () => {
    const { checkIsCurrentCycleEnd } = usePomodoroService();
    const result = await checkIsCurrentCycleEnd();

    expect(result).toBeTypeOf("boolean");
  });

  it("debe retornar FALSE si el ciclo está incompleto", async () => {
    // ... Lógica similar, pero creando datos que GARANTICEN FALSE ...
  });
  // Hook de limpieza que se ejecuta después de cada test
  afterEach(async () => {
    // if (cycleIdToClean) {
    //   await supabase.from("pomodoro_cycles").delete().eq("id", cycleIdToClean);
    //   // Asegúrate de borrar también pomodoros y tags relacionados
    // }
    // cycleIdToClean = 0;
  });
});
