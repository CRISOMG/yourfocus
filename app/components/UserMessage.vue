<script setup lang="ts">
const props = withDefaults(
  defineProps<{
    text: string;
    canAppendResponse?: boolean;
    isAppending?: boolean;
  }>(),
  {
    canAppendResponse: false,
    isAppending: false,
  },
);

const emit = defineEmits<{
  appendResponse: [];
}>();

const isExpanded = ref(false);
const isLong = computed(
  () => props.text.length > 300 || props.text.split("\n").length > 4,
);

function parseMarkdownLinks(text: string) {
  // Simple HTML escape to prevent XSS
  const escaped = text
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#039;");

  // Parse [text](link) -> <a href="link" target="_blank" ...>text</a>
  return escaped.replace(
    /\[([^\]]+)\]\(([^)]+)\)/g,
    '<a href="$2" target="_blank" rel="noopener noreferrer" class="underline decoration-dashed underline-offset-4 decoration-neutral-500 hover:decoration-solid hover:text-primary transition-all">$1</a>',
  );
}
</script>

<template>
  <div
    class="relative group py-2 pl-2 pr-2 border-l-2 border-green-500/30 rounded-lg flex flex-col gap-1.5"
  >
    <div
      class="text-sm transition-all duration-200 overflow-x-auto"
      :class="{
        'line-clamp-3 max-h-[4.5em] overflow-hidden': isLong && !isExpanded,
      }"
      v-html="parseMarkdownLinks(text)"
    />

    <UButton
      v-if="isLong"
      :icon="isExpanded ? 'i-lucide-chevron-up' : 'i-lucide-chevron-down'"
      size="xs"
      color="neutral"
      variant="solid"
      :aria-label="isExpanded ? 'Collapse message' : 'Expand message'"
      class="absolute -top-2.5 -right-2.5 rounded-full shadow-sm z-10 opacity-0 group-hover:opacity-100 focus:opacity-100 transition-opacity"
      @click="isExpanded = !isExpanded"
    />

    <!-- Append Agent Response Action -->
    <div
      v-if="canAppendResponse"
      class="mt-1 pt-1.5 border-t border-neutral-700/30 flex items-center justify-between gap-2 flex-wrap"
    >
      <span class="text-xs text-muted flex items-center gap-1 font-mono">
        <UIcon name="i-lucide-notebook-pen" class="size-3.5 text-amber-500" />
        Bitácora (sin procesar)
      </span>
      <UButton
        size="xs"
        color="primary"
        variant="subtle"
        icon="i-lucide-sparkles"
        :loading="isAppending"
        :disabled="isAppending"
        class="transition-transform active:scale-95"
        @click.stop="emit('appendResponse')"
      >
        Append Agent Response
      </UButton>
    </div>
  </div>
</template>
