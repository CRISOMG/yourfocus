import { ref, onMounted, onUnmounted } from "vue";
import { useNetwork } from "@vueuse/core";

export interface QueuedRequest {
  id: string; // ID assigned by Workbox in IndexedDB
  queueName: string;
  requestData: {
    url: string;
    method: string;
    body?: ArrayBuffer | Blob;
  };
  timestamp: number;
}

export function useOfflineSync() {
  const { isOnline } = useNetwork();
  const pendingOperations = ref<QueuedRequest[]>([]);
  
  // Backsync logic removed per user request to simplify architecture.
  const fetchQueue = async () => {};

  return {
    isOnline,
    pendingOperations,
    fetchQueue,
  };
}
