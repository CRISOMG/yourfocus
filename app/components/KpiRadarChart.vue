<template>
  <div class="w-full h-full min-h-[300px] flex items-center justify-center relative">
    <div v-if="isLoading" class="flex flex-col items-center justify-center opacity-50">
      <UIcon name="i-lucide-loader" class="w-8 h-8 mb-2 animate-spin" />
      <p class="text-sm">Analizando datos...</p>
    </div>
    <Radar v-else-if="chartData.datasets[0].data.some(v => v > 0)" :data="chartData" :options="chartOptions" />
    <div v-else class="flex flex-col items-center justify-center opacity-50">
      <UIcon name="i-lucide-activity" class="w-8 h-8 mb-2" />
      <p class="text-sm text-center">Sin datos suficientes.<br>¡Completa pomodoros o tareas para iluminar tu radar!</p>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed, ref, onMounted } from 'vue';
import {
  Chart as ChartJS,
  RadialLinearScale,
  PointElement,
  LineElement,
  Filler,
  Tooltip,
  Legend
} from 'chart.js';
import { Radar } from 'vue-chartjs';

ChartJS.register(
  RadialLinearScale,
  PointElement,
  LineElement,
  Filler,
  Tooltip,
  Legend
);

const props = defineProps<{
  mode: 'total' | 'velocity';
}>();

const supabase = useSupabaseClient();
const isLoading = ref(true);
const kpiData = ref<any>(null);
const kpiVelocity = ref<any>(null);

onMounted(async () => {
  isLoading.value = true;
  try {
    // Current accumulated data (Last 7 days)
    const { data: currentData } = await supabase.rpc('get_user_kpi_stats', { p_timeframe_days: 7 });
    
    // Past accumulated data (Last 14 days minus 7 days, approximated by just fetching 14 days and doing delta)
    // For a real velocity metric we'd ideally get exactly window [t-14, t-7] vs [t-7, t]
    const { data: pastData } = await supabase.rpc('get_user_kpi_stats', { p_timeframe_days: 14 });
    
    kpiData.value = currentData || { enfoque: 0, agencia: 0, curiosidad: 0, interes: 0, competencia: 0, lucidez: 0 };
    
    if (currentData && pastData) {
      // Velocity = Current 7 days - (Past 14 days - Current 7 days)
      kpiVelocity.value = {
        enfoque: Math.max(0, currentData.enfoque - (pastData.enfoque - currentData.enfoque)),
        agencia: Math.max(0, currentData.agencia - (pastData.agencia - currentData.agencia)),
        curiosidad: Math.max(0, currentData.curiosidad - (pastData.curiosidad - currentData.curiosidad)),
        interes: Math.max(0, currentData.interes - (pastData.interes - currentData.interes)),
        competencia: Math.max(0, currentData.competencia - (pastData.competencia - currentData.competencia)),
        lucidez: Math.max(0, currentData.lucidez - (pastData.lucidez - currentData.lucidez))
      };
    }
  } catch (error) {
    console.error("Error fetching KPI stats:", error);
  } finally {
    isLoading.value = false;
  }
});

const chartData = computed(() => {
  const isVelocity = props.mode === 'velocity';
  
  const rawData = isVelocity ? kpiVelocity.value : kpiData.value;
  const values = rawData 
    ? [rawData.enfoque, rawData.agencia, rawData.curiosidad, rawData.interes, rawData.competencia, rawData.lucidez]
    : [0, 0, 0, 0, 0, 0];
  
  return {
    labels: [
      'Enfoque',
      'Agencia',
      'Curiosidad',
      'Interés',
      'Competencia',
      'Lucidez'
    ],
    datasets: [
      {
        label: isVelocity ? 'Tasa de Cambio (+Δ)' : 'Nivel Acumulado (7d)',
        backgroundColor: 'rgba(255, 159, 64, 0.2)', // Peach-like color
        borderColor: 'rgba(255, 159, 64, 1)',
        pointBackgroundColor: 'rgba(255, 159, 64, 1)',
        pointBorderColor: '#fff',
        pointHoverBackgroundColor: '#fff',
        pointHoverBorderColor: 'rgba(255, 159, 64, 1)',
        data: values,
        borderWidth: 2,
      }
    ]
  };
});

const chartOptions = computed(() => {
  return {
    responsive: true,
    maintainAspectRatio: false,
    scales: {
      r: {
        angleLines: {
          color: 'rgba(150, 150, 150, 0.2)'
        },
        grid: {
          color: 'rgba(150, 150, 150, 0.2)'
        },
        pointLabels: {
          color: 'rgba(150, 150, 150, 0.8)',
          font: {
            size: 11,
            family: 'Inter, sans-serif'
          }
        },
        ticks: {
          display: false, // Hide the numbers on the axis
          min: 0,
        }
      }
    },
    plugins: {
      legend: {
        labels: {
          color: 'rgba(150, 150, 150, 0.8)'
        }
      }
    }
  };
});
</script>
