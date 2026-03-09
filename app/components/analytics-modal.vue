<template>
  <UModal
    :ui="{ body: 'sm:p-0' }"
    :overlay="false"
    v-model:open="isOpen"
    title="Analytics"
  >
    <template #body>
      <UTabs :default-value="'timeline'" :items="tabs" class="w-full">
        <template #content="{ item }">
          <div v-if="item.value === 'timeline'" class="flex h-[80vh] p-0">
            <TimeGrid />
          </div>

          <div
            v-if="item.value === 'okrs'"
            class="flex flex-col h-[80vh] p-[4px] gap-4 overflow-y-auto"
          >
            <!-- Header -->
            <div class="flex justify-between items-center">
              <div>
                <h2 class="text-xl font-bold">Mis Objetivos (OKRs)</h2>
                <p class="text-xs text-[var(--ui-text-dimmed)] mt-1">
                  Mide tu progreso atómico.
                </p>
              </div>
              <UButton
                icon="i-lucide-plus"
                color="primary"
                size="sm"
                @click="isAddingObjective = !isAddingObjective"
              >
                Objetivo
              </UButton>
            </div>

            <!-- Form: Add Objective -->
            <UForm
              v-if="isAddingObjective"
              :schema="objectiveSchema"
              :state="stateObjective"
              class="space-y-3 p-1 border border-[var(--ui-border)] rounded-lg bg-[var(--ui-bg-elevated)]"
              @submit="submitObjective"
            >
              <UFormField label="Título del Objetivo" name="title">
                <UInput
                  v-model="stateObjective.title"
                  placeholder="Ej. Dominar Inteligencia Artificial"
                  :disabled="isLoading"
                  class="w-full"
                />
              </UFormField>
              <UFormField label="Descripción (Opcional)" name="description">
                <UTextarea
                  v-model="stateObjective.description"
                  placeholder="Detalles sobre por qué esto es importante..."
                  :rows="2"
                  autoresize
                  :disabled="isLoading"
                  class="w-full"
                />
              </UFormField>
              <div class="flex justify-end gap-2 mt-2">
                <UButton
                  variant="ghost"
                  color="neutral"
                  size="sm"
                  @click="isAddingObjective = false"
                >
                  Cancelar
                </UButton>
                <UButton
                  type="submit"
                  color="primary"
                  size="sm"
                  :loading="isLoading"
                >
                  Guardar
                </UButton>
              </div>
            </UForm>

            <USeparator v-if="objectives.length > 0" />

            <!-- Empty State -->
            <div
              v-if="objectives.length === 0 && !isAddingObjective && !isLoading"
              class="flex flex-col items-center justify-center p-8 text-center gap-3 opacity-70"
            >
              <UIcon name="i-lucide-target" class="w-12 h-12" />
              <p>
                No tienes objetivos configurados. Empieza creando tu gran meta.
              </p>
            </div>

            <!-- Objectives List -->
            <div class="space-y-4 pb-12">
              <UCard
                v-for="obj in objectives"
                :key="obj.id"
                class="overflow-hidden"
              >
                <template #header>
                  <div class="flex justify-between items-start gap-2">
                    <div class="flex-1">
                      <h3 class="font-semibold text-base leading-tight">
                        {{ obj.title }}
                      </h3>
                      <p
                        class="text-xs text-[var(--ui-text-dimmed)] mt-1"
                        v-if="obj.description"
                      >
                        {{ obj.description }}
                      </p>
                    </div>
                    <UButton
                      icon="i-lucide-trash-2"
                      color="error"
                      variant="ghost"
                      size="xs"
                      @click="handleDeleteObjective(obj.id)"
                    />
                  </div>
                </template>

                <div class="p-4 space-y-4">
                  <!-- List Key Results -->
                  <div
                    v-for="kr in obj.key_results"
                    :key="kr.id"
                    class="space-y-2 pb-3 border-b border-[var(--ui-border)] last:border-0 last:pb-0"
                  >
                    <div class="flex justify-between items-start gap-2">
                      <div class="flex-1">
                        <span class="font-medium text-sm leading-tight block">
                          {{ kr.title }}
                        </span>

                        <div class="flex gap-1 mt-1.5 flex-wrap">
                          <UBadge size="xs" variant="subtle" color="primary">
                            {{ kr.current_value }} / {{ kr.target_value }}
                          </UBadge>
                          <UBadge size="xs" variant="soft" color="neutral">
                            {{ formatMetric(kr.metric_type) }}
                          </UBadge>
                        </div>
                      </div>

                      <UButton
                        icon="i-lucide-x"
                        variant="ghost"
                        color="neutral"
                        size="xs"
                        class="opacity-50 hover:opacity-100 hover:text-red-500"
                        @click="handleDeleteKeyResult(kr.id)"
                      />
                    </div>
                    <!-- ProgressBar (UMeter/UProgress equlivalent) -->
                    <div
                      class="w-full bg-[var(--ui-bg-hover)] rounded-full h-1.5 overflow-hidden"
                    >
                      <div
                        class="bg-primary-500 h-1.5"
                        :style="{
                          width: `${Math.min((kr.current_value / kr.target_value) * 100, 100)}%`,
                        }"
                      ></div>
                    </div>

                    <div class="flex flex-wrap gap-1 mt-1">
                      <UBadge
                        v-for="t in kr.tags"
                        :key="t.tag_id"
                        size="xs"
                        variant="outline"
                        class="!text-[10px]"
                      >
                        {{ t.tag.label }}
                      </UBadge>
                    </div>
                  </div>

                  <!-- Add KR Button -->
                  <UButton
                    v-if="activeObjectiveId !== obj.id"
                    variant="soft"
                    color="neutral"
                    icon="i-lucide-plus"
                    size="xs"
                    class="w-full justify-center"
                    @click="openAddKr(obj.id)"
                  >
                    Nuevo Key Result
                  </UButton>

                  <!-- Form: Add KR -->
                  <UForm
                    v-if="activeObjectiveId === obj.id"
                    :schema="krSchema"
                    :state="stateKr"
                    class="space-y-3 p-3 bg-[var(--ui-bg-hover)] border border-[var(--ui-border)] rounded-md mt-2"
                    @submit="submitKeyResult($event, obj.id)"
                  >
                    <UFormField label="Métrica Clave (Key Result)" name="title">
                      <UInput
                        v-model="stateKr.title"
                        size="xs"
                        placeholder="Ej. Completar 50 pomodoros"
                        :disabled="isLoading"
                        class="w-full"
                      />
                    </UFormField>
                    <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
                      <UFormField label="Meta Numérica" name="target">
                        <UInput
                          type="number"
                          v-model="stateKr.target"
                          min="1"
                          size="xs"
                          :disabled="isLoading"
                          class="w-full"
                        />
                      </UFormField>
                      <UFormField label="Tipo de Métrica" name="metric">
                        <USelectMenu
                          v-model="stateKr.metric"
                          :items="metricOptions"
                          value-key="value"
                          label-key="label"
                          size="xs"
                          :disabled="isLoading"
                          class="w-full"
                        />
                      </UFormField>
                    </div>

                    <UFormField label="Etiquetas Asociadas" name="tags">
                      <p
                        class="text-[10px] leading-tight text-[var(--ui-text-dimmed)] mb-2 mt-[-4px]"
                      >
                        Cualquier acción completada con estas etiquetas sumará
                        automáticamente al Key Result.
                      </p>
                      <PomodoroTagSelector 
                        v-model:tags="stateKr.tags"
                        @add="onAddKrTag"
                        @remove="onRemoveKrTag"
                      />
                    </UFormField>

                    <div class="flex justify-end gap-2 pt-2">
                      <UButton
                        variant="ghost"
                        size="xs"
                        color="neutral"
                        @click="activeObjectiveId = null"
                      >
                        Cancelar
                      </UButton>
                      <UButton
                        type="submit"
                        size="xs"
                        color="primary"
                        :loading="isLoading"
                      >
                        Guardar KR
                      </UButton>
                    </div>
                  </UForm>
                </div>
              </UCard>
            </div>
          </div>

          <!-- KPIs Tab -->
          <div
            v-if="item.value === 'kpis'"
            class="flex flex-col h-[80vh] p-[4px] gap-4 overflow-y-auto"
          >
            <!-- Header -->
            <div class="flex justify-between items-center px-1">
              <div>
                <h2 class="text-xl font-bold">KPIs Core (Salud)</h2>
                <p class="text-xs text-[var(--ui-text-dimmed)] mt-1">
                  Radar de tus 6 cualidades cognitivas.
                </p>
              </div>

              <!-- Toggle -->
              <div class="flex rounded-md overflow-hidden bg-[var(--ui-bg-elevated)] border border-[var(--ui-border)] p-0.5">
                <UButton 
                  size="xs" 
                  :variant="kpiViewMode === 'total' ? 'solid' : 'ghost'" 
                  color="neutral" 
                  @click="kpiViewMode = 'total'"
                  class="rounded-sm"
                >
                  Acumulado
                </UButton>
                <UButton 
                  size="xs" 
                  :variant="kpiViewMode === 'velocity' ? 'solid' : 'ghost'" 
                  color="neutral" 
                  @click="kpiViewMode = 'velocity'"
                  class="rounded-sm"
                >
                  Tasa de Cambio
                </UButton>
              </div>
            </div>

            <!-- Chart Placeholder -->
            <UCard class="flex-1 flex flex-col items-center justify-center p-8 text-center border-dashed bg-transparent shadow-none" :ui="{ body: { base: 'flex flex-col items-center justify-center h-full' } }">
              <UIcon name="i-lucide-radar" class="w-16 h-16 opacity-30 mb-4" />
              <p class="font-medium text-lg opacity-80">Configuración del Radar Chart</p>
              <p class="text-xs opacity-60 mt-2 max-w-xs mx-auto">
                El gráfico de radar requiere la instalación de una librería como Chart.js (vue-chartjs) para renderizarse.
              </p>
            </UCard>
          </div>
        </template>
      </UTabs>
    </template>
  </UModal>
</template>

<script setup lang="ts">
import { z } from "zod";
import type { DbMetricCategory } from "~~/shared/types/okr";
import { useOkrController } from "~~/shared/composables/okr/use-okr-controller";
import { useTagController } from "~/composables/tag/use-tag-controller";
import PomodoroTagSelector from "./PomodoroTagSelector.vue";

const isOpen = defineModel<boolean>({ default: false });
const toast = useToast();

const tabs = [
  { label: "Timeline", value: "timeline", icon: "i-lucide-clock" },
  { label: "OKRs", value: "okrs", icon: "i-lucide-target" },
  { label: "KPIs", value: "kpis", icon: "i-lucide-activity" },
];

const kpiViewMode = ref<"total" | "velocity">("total");

const {
  objectives,
  isLoading,
  error,
  handleCreateObjective,
  handleDeleteObjective,
  handleCreateKeyResult,
  handleDeleteKeyResult,
} = useOkrController();

// --- Objectives state ---
const isAddingObjective = ref(false);

const objectiveSchema = z.object({
  title: z.string().min(3, "El título debe tener al menos 3 caracteres"),
  description: z.string().optional(),
});

const stateObjective = reactive({
  title: "",
  description: "",
});

async function submitObjective(event: any) {
  try {
    await handleCreateObjective(event.data.title, event.data.description);
    stateObjective.title = "";
    stateObjective.description = "";
    isAddingObjective.value = false;
    toast.add({ title: "Objetivo creado exitosamente", color: "success" });
  } catch (e: any) {
    toast.add({
      title: "Error al crear",
      description: e.message,
      color: "error",
    });
  }
}

// --- Key Results state ---
const activeObjectiveId = ref<string | null>(null);

const krSchema = z.object({
  title: z.string().min(3, "La métrica debe tener al menos 3 caracteres"),
  target: z
    .number()
    .min(1, "La meta debe ser numéricamente válida y mayor a 0"),
  metric: z.string(),
  tags: z.array(z.any()).optional(),
});

const stateKr = reactive({
  title: "",
  target: 10,
  metric: "COUNT_ATOMIC",
  tags: [] as any[],
});

const tagController = useTagController();

function onAddKrTag(tagId: number) {
  const tag = tagController.userTags.value.find((t) => t.id === tagId);
  if (tag && !stateKr.tags.find((t) => t.id === tagId)) {
    stateKr.tags.push(tag);
  }
}

function onRemoveKrTag(tagId: number) {
  stateKr.tags = stateKr.tags.filter((t) => t.id !== tagId);
}

const metricOptions = [
  { label: "Acciones Atómicas (Tareas)", value: "COUNT_ATOMIC" },
  { label: "Tiempo (Pomodoros)", value: "TIME_INVESTMENT" },
  { label: "Conocimiento (Notas)", value: "KNOWLEDGE_DENSITY" },
  { label: "Calidad (Feedback)", value: "QUALITY_SCORE" },
];

function formatMetric(metric: string) {
  const opt = metricOptions.find((o) => o.value === metric);
  return opt ? opt.label : metric;
}

function openAddKr(objectiveId: string) {
  activeObjectiveId.value = objectiveId;
  stateKr.title = "";
  stateKr.target = 10;
  stateKr.metric = "COUNT_ATOMIC";
  stateKr.tags = [];
}

async function submitKeyResult(event: any, objectiveId: string) {
  try {
    const formattedTags = event.data.tags.map((t: any) => ({
      tagId: t.id,
      weight: 1, // Default weight for now
    }));

    await handleCreateKeyResult(
      objectiveId,
      event.data.title,
      event.data.metric as DbMetricCategory,
      event.data.target,
      formattedTags,
    );

    activeObjectiveId.value = null;
    toast.add({ title: "Key Result añadido exitosamente", color: "success" });
  } catch (e: any) {
    toast.add({
      title: "Error al añadir KR",
      description: e.message,
      color: "error",
    });
  }
}
</script>
