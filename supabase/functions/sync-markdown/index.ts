import { createClient } from "@supabase/supabase-js";
import fm from "front-matter";

// When an object is inserted or updated in storage.objects, this webhook is called
interface WebhookPayload {
  type: "INSERT" | "UPDATE" | "DELETE";
  table: string;
  schema: string;
  record: {
    id: string;
    bucket_id: string;
    name: string;
    owner: string; // The user_id
    metadata: Record<string, unknown>;
    updated_at: string;
  };
  old_record: {
    name: string;
    owner: string;
  } | null;
}

Deno.serve(async (req) => {
  try {
    const payload: WebhookPayload = await req.json();

    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    // Initial check for table
    if (payload.table !== "objects" || payload.schema !== "storage") {
      return new Response("Ignored: Not storage.objects", { status: 200 });
    }

    // Handle DELETES
    if (payload.type === "DELETE") {
      if (payload.old_record?.name?.endsWith(".md")) {
        await supabaseAdmin
          .from("notes")
          .delete()
          .eq("storage_path", payload.old_record.name)
          .eq("user_id", payload.old_record.owner);
      }
      return new Response("Deleted note gracefully", { status: 200 });
    }

    // Handle INSERT / UPDATE bounds
    if (!payload.record?.name?.endsWith(".md")) {
      return new Response("Ignored: Not a markdown file", { status: 200 });
    }

    const { name, bucket_id, owner } = payload.record;

    // Download the file
    const { data: fileData, error: downloadError } = await supabaseAdmin.storage
      .from(bucket_id)
      .download(name);

    if (downloadError || !fileData) {
      console.error("Failed to download file:", downloadError);
      return new Response("Failed to download", { status: 500 });
    }

    const textPayload = await fileData.text();
    let frontmatter: Record<string, unknown> = {};
    let title = name.split("/").pop()?.replace(".md", "");
    const tagsToAssign: string[] = [];

    // Parse frontmatter
    try {
      const parsed = fm(textPayload);      
      frontmatter = parsed.attributes as Record<string, unknown> || {};
      
      // Extract title if exists
      if (typeof frontmatter.title === 'string') {
        title = frontmatter.title;
      }
      
      // Extract tags
      const rawTags = frontmatter.tags;
      if (rawTags) {
         let parsedTags: string[] = [];
         if (Array.isArray(rawTags)) {
           parsedTags = rawTags.filter(t => typeof t === 'string');
         } else if (typeof rawTags === 'string') {
           parsedTags = rawTags.split(",").map(t => t.trim());
         }
         tagsToAssign.push(...parsedTags);
      }
    } catch (e) {
      console.log("Could not parse frontmatter accurately", e);
    }

    // Try to extract #tags from the body if no frontmatter tags
    const regex = /(?:^|\s)#([a-zA-Z0-9_]+)/g;
    let match;
    while ((match = regex.exec(textPayload)) !== null) {
      if (match[1] && !tagsToAssign.includes(match[1])) {
        tagsToAssign.push(match[1].toLowerCase());
      }
    }

    // Upsert the note
    const { data: note, error: noteError } = await supabaseAdmin
      .from("notes")
      .upsert({
         user_id: owner,
         storage_path: name,
         title: title,
         frontmatter: frontmatter,
         updated_at: new Date().toISOString()
      }, { onConflict: "user_id,storage_path" })
      .select("id")
      .single();

    if (noteError) {
      console.error("Failed to upsert note:", noteError);
      return new Response("Failed to upsert note", { status: 500 });
    }

    // Add tags to `notes_tags`. First collect tag IDs
    const finalTagIds: number[] = [];
    for (const label of tagsToAssign) {
      const normalized = label.trim().toLowerCase();
      if (!normalized) continue;

      // Find or create tag
      const { data: existingTag } = await supabaseAdmin
        .from("tags")
        .select("id")
        .or(`user_id.eq.${owner},user_id.is.null`)
        .eq("label", normalized)
        .maybeSingle();

      if (existingTag) {
        if (!finalTagIds.includes(existingTag.id)) {
          finalTagIds.push(existingTag.id);
        }
      } else {
        const { data: newTag, error: tagError } = await supabaseAdmin
          .from("tags")
          .insert({ label: normalized, user_id: owner })
          .select("id")
          .single();

        if (!tagError && newTag) {
          finalTagIds.push(newTag.id);
        }
      }
    }

    // Delete existing tags for this note
    await supabaseAdmin
      .from("notes_tags")
      .delete()
      .eq("note_id", note.id);

    // Insert new tags
    if (finalTagIds.length > 0) {
      const noteTagRows = finalTagIds.map(tagId => ({
        note_id: note.id,
        tag_id: tagId
      }));
      await supabaseAdmin.from("notes_tags").insert(noteTagRows);
    }

    return new Response(JSON.stringify({ success: true, note_id: note.id, tags: finalTagIds }), {
      headers: { "Content-Type": "application/json" }
    });
  } catch (error) {
    const err = error as Error;
    console.error("Webhook processing error:", err);
    return new Response(JSON.stringify({ error: err.message }), { status: 500 });
  }
});
