<script setup lang="ts">
import type { FormError, FormSubmitEvent } from '@nuxt/ui'
const supabase = useSupabaseClient()
const config = useRuntimeConfig()
const state = reactive({
    email: config.public.test_email || '',
})

type Schema = typeof state

function validate(state: Partial<Schema>): FormError[] {
    const errors = []
    if (!state.email) errors.push({ name: 'email', message: 'Required' })
    return errors
}

const toast = useToast()
async function onSubmit(event: FormSubmitEvent<Schema>) {
    const { error } = await supabase.auth.resetPasswordForEmail(event.data.email as unknown as string, { redirectTo: '/update-password' })
    if (error) {
        toast.add({ title: 'Error', description: error.message, color: 'error' })
        return
    } else {
        toast.add({ title: 'Success', description: 'The form has been submitted.', color: 'success' })
        navigateTo('/login')
    }
}
</script>

<template>
    <div class="flex items-center justify-center h-screen">
        <UForm :validate="validate" :state="state" class="space-y-4" @submit="onSubmit">
            <UFormField label="Send reset password email" name="email">
                <div class="flex items-center gap-1">
                    <UInput class="w-56" v-model="state.email" type="email" placeholder="Enter your email" size="md" />
                    <UButton type="submit" icon="i-lucide-send-horizontal" size="md" />
                </div>
            </UFormField>
        </UForm>
    </div>
</template>
