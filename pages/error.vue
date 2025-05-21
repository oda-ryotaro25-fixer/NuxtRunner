<template>
  <div>
    <h1>Error Page</h1>
    <p>Something went wrong.</p>
  </div>
</template>

<script setup lang="ts">
import type { NuxtError } from "#app";

const props = defineProps({
  error: Object as () => NuxtError,
});
</script>
