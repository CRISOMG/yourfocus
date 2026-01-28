<script setup lang="ts">
const value = ref("");

// const id = "Modelo Mental - Jerarquía de Visión y Dominio.md";
// const id = "Seniority Path - Arquitectura de Carrera y Visión.md";

const { id } = useRoute().params;

const { data } = await useFetch(
  `/api/google-drive/search?name=${id as string}`,
);

value.value = data?.value?.content as string;

useHead({
  title: id as string,
  meta: [
    { charset: "utf-8" },
    { name: "viewport", content: "width=device-width, initial-scale=1" },
    { name: "description", content: id },
  ],
  link: [{ rel: "icon", type: "image/x-icon", href: "/favicon.ico" }],
});

import { parseMarkdown } from "@nuxtjs/mdc/runtime";

const { data: ast } = await useAsyncData("markdown", () =>
  parseMarkdown(value.value),
);
</script>

<template>
  <!-- <UEditor
    :editable="false"
    v-model="value"
    content-type="markdown"
    class="w-full min-h-21 mb-8"
  /> -->
  <MDCRenderer :body="ast?.body" :data="ast?.data" />
</template>
