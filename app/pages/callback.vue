<script setup lang="ts">
import type { EmailOtpType } from '@supabase/supabase-js'

const supabase = useSupabaseClient()
const route = useRoute()
const router = useRouter()

const verifyingOtp = ref(false)
const error = ref<string | null>(null)

onMounted(async () => {
  const token_hash = route.query.token_hash as string
  const type = route.query.type as EmailOtpType

  verifyingOtp.value = true
  try {
    const { error } = await supabase.auth.verifyOtp({ token_hash, type })
    if (error) throw error
    router.push('/dashboard')
  } catch (e) {
    console.error(isError(e) ? e.message : 'Error resetting password.')
  }
  verifyingOtp.value = false
})
</script>

<template>
  <div v-if="verifyingOtp">Verifying...</div>
  <div v-else-if="error">{{ error }}</div>
</template>