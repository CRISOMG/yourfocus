import type { Database } from "~/types/database.types";

type Profile = Database["public"]["Tables"]["profiles"];

export const useProfileRepository = () => {
  const supabase = useSupabaseClient<Database>();

  async function getOne(id: string) {
    const { data, error } = await supabase
      .from("profiles")
      .select("*")
      .eq("id", id)
      .single();

    if (error) throw error;
    return data;
  }

  async function update(id: string, profile: Profile["Update"]) {
    const { data, error } = await supabase
      .from("profiles")
      .update(profile)
      .eq("id", id)
      .select()
      .single();

    if (error) throw error;
    return data;
  }

  async function uploadAvatar(userId: string, file: File) {
    const fileExt = file.name.split(".").pop();
    const fileName = `${userId}/${"avatar"}.${fileExt}`;
    const filePath = `${fileName}`;

    const { error: uploadError } = await supabase.storage
      .from("avatars")
      .upload(filePath, file);

    if (uploadError) throw uploadError;

    const { data } = supabase.storage.from("avatars").getPublicUrl(filePath);
    return data.publicUrl;
  }

  return {
    getOne,
    update,
    uploadAvatar,
  };
};
