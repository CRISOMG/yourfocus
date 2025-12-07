<template>
  <UContainer class="max-w-4xl">
    <div class="py-4 flex items-baseline justify-between">
      <div class="flex items-baseline">
        <i class="mr-1 w-6 flex self-center"
          ><img src="/check-focus.png" alt="focus"
        /></i>
        <p class="font-bold">Yourfocus</p>
      </div>

      <div class="flex self-end gap-2">
        <UButton icon="i-lucide:chart-column">Report</UButton>
        <UButton icon="i-lucide:settings">Settings</UButton>

        <UDropdownMenu
          :content="{ align: 'end' }"
          :items="items"
          :ui="{
            content: 'w-48',
          }"
        >
          <UButton
            :avatar="{
              src: 'user-white.png',
            }"
            size="md"
            color="neutral"
            variant="outline"
          />
        </UDropdownMenu>
      </div>
    </div>
    <USeparator />
    <div>
      <PomofocusClone :user_id="user_id" />
    </div>

    <template>
      <UModal
        :ui="{ content: 'top-60' }"
        :overlay="false"
        v-model:open="openProfileModal"
        title="Profile"
      >
        <template #body>
          <div class="flex">
            <div class="flex p-4">
              <UFileUpload
                size="xl"
                v-model="fileUpload.avatar"
                @change="onFileChange"
                color="neutral"
                accept="image/*"
                :ui="{
                  file: '[&_img]:object-contain',
                }"
              >
              </UFileUpload>
            </div>

            <div class="flex flex-col w-full">
              <p class="font-bold text-2xl mt-6 capitalize">
                {{ user?.user_metadata?.fullname }}
              </p>
              <USeparator class="mb-2" />
              <p class="font-bold">{{ user?.email }}</p>
            </div>
          </div>
        </template>
        <template #footer>
          <div class="flex gap-1 justify-end w-full">
            <UButton>Cancel</UButton>
            <UButton
              @click="
                handleUpdateProfile({ fullname: user?.user_metadata?.fullname })
              "
              color="success"
              >Save</UButton
            >
          </div>
        </template>
      </UModal>
    </template>
  </UContainer>
</template>

<script setup lang="ts">
import type { DropdownMenuItem } from "@nuxt/ui";
import type { JwtPayload } from "@supabase/supabase-js";
import z, { file } from "zod";
import { useProfileController } from "~/composables/profile/use-profile-controller";

const supabase = useSupabaseClient();
const user = useSupabaseUser();
const toast = useSuccessErrorToast();
const user_id = computed(() => {
  return user.value?.sub as string;
});

async function urlToFile(url: string, filename: string) {
  const response = await fetch(url);
  const blob = await response.blob();
  const mimeType = blob.type;
  const file = new File([blob], filename, { type: mimeType });
  return file;
}
const fileUpload = reactive<{ avatar: File | undefined }>({
  avatar: undefined,
});

const openProfileModal = ref(false);

const items = ref<DropdownMenuItem[][]>([
  [
    {
      label: "Profile",
      icon: "i-lucide-user",
      onSelect: () => {
        openProfileModal.value = true;
      },
    },

    {
      label: "Keyboard shortcuts",
      icon: "i-lucide-monitor",
    },
  ],

  [
    {
      label: "Logout",
      icon: "i-lucide-log-out",
      kbds: ["shift", "meta", "q"],
      onSelect() {
        supabase.auth.signOut();
      },
    },
  ],
]);

const { profile, handleUpdateProfile, handleUploadAvatar } =
  useProfileController();
watch(profile, async () => {
  if (profile.value) {
    const file = await urlToFile(
      (profile.value?.avatar_url as string) || "/user-white.png",
      "avatar"
    );
    fileUpload.avatar = file;
  }
});

// To update profile
const updateData = async () => {
  await handleUpdateProfile({ fullname: "New Name" });
};

// To upload avatar
const onFileChange = async (event) => {
  console.log(fileUpload.avatar, event);
  const file = fileUpload.avatar;
  // const file = event.target.files[0];
  if (file) {
    const url = await handleUploadAvatar(file);
  }
};
</script>
