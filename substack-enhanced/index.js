import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";

// ---------------------------------------------------------------------------
// Configuration from environment
// ---------------------------------------------------------------------------
const PUBLICATION_URL = (process.env.SUBSTACK_PUBLICATION_URL || "").replace(
  /\/$/,
  ""
);
const SESSION_TOKEN = process.env.SUBSTACK_SESSION_TOKEN || "";
const USER_ID = process.env.SUBSTACK_USER_ID || "";

const API_BASE = `${PUBLICATION_URL}/api/v1`;
const AUTH_COOKIE = `substack.sid=${SESSION_TOKEN}; connect.sid=${SESSION_TOKEN};`;

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/** Standard headers for every Substack API request. */
function headers() {
  return {
    Cookie: AUTH_COOKIE,
    "Content-Type": "application/json",
    Referer: `${PUBLICATION_URL}/publish/post`,
    "User-Agent": "substack-enhanced-mcp/1.0",
  };
}

/** Thin wrapper around fetch that returns parsed JSON or throws. */
async function api(method, path, body = undefined) {
  const url = path.startsWith("http") ? path : `${API_BASE}${path}`;
  const opts = { method, headers: headers() };
  if (body !== undefined) {
    opts.body = JSON.stringify(body);
  }
  const res = await fetch(url, opts);
  const text = await res.text();
  if (!res.ok) {
    throw new Error(
      `Substack API ${method} ${path} \u2192 ${res.status}: ${text.slice(0, 500)}`
    );
  }
  try {
    return JSON.parse(text);
  } catch {
    return text; // some endpoints return empty or non-JSON
  }
}

/**
 * Convert plain text body into the Tiptap ProseMirror JSON that Substack
 * expects for draft_body.  Splits on double-newlines into paragraphs and
 * supports simple Markdown-ish conventions:
 *   # Heading 1 \u2026 ###### Heading 6
 *   **bold**  *italic*  [link text](url)
 *   - bullet items
 *   1. ordered items
 *   --- horizontal rule
 */
function textToDoc(text) {
  const lines = text.split("\n");
  const content = [];
  let i = 0;

  while (i < lines.length) {
    const line = lines[i];

    // Blank line \u2192 skip
    if (line.trim() === "") {
      i++;
      continue;
    }

    // Horizontal rule
    if (/^-{3,}$/.test(line.trim())) {
      content.push({ type: "horizontal_rule" });
      i++;
      continue;
    }

    // Heading
    const headingMatch = line.match(/^(#{1,6})\s+(.+)$/);
    if (headingMatch) {
      content.push({
        type: "heading",
        attrs: { level: headingMatch[1].length },
        content: parseInline(headingMatch[2]),
      });
      i++;
      continue;
    }

    // Unordered list
    if (/^\s*[-*]\s+/.test(line)) {
      const items = [];
      while (i < lines.length && /^\s*[-*]\s+/.test(lines[i])) {
        items.push({
          type: "list_item",
          content: [
            {
              type: "paragraph",
              content: parseInline(lines[i].replace(/^\s*[-*]\s+/, "")),
            },
          ],
        });
        i++;
      }
      content.push({ type: "bullet_list", content: items });
      continue;
    }

    // Ordered list
    if (/^\s*\d+\.\s+/.test(line)) {
      const items = [];
      while (i < lines.length && /^\s*\d+\.\s+/.test(lines[i])) {
        items.push({
          type: "list_item",
          content: [
            {
              type: "paragraph",
              content: parseInline(lines[i].replace(/^\s*\d+\.\s+/, "")),
            },
          ],
        });
        i++;
      }
      content.push({ type: "ordered_list", attrs: { start: 1 }, content: items });
      continue;
    }

    // Regular paragraph
    content.push({ type: "paragraph", content: parseInline(line) });
    i++;
  }

  return { type: "doc", content };
}

/** Parse inline Markdown-ish markup into Tiptap text nodes with marks. */
function parseInline(text) {
  const nodes = [];
  // Regex for **bold**, *italic*, [link](url)
  const regex = /(\*\*(.+?)\*\*)|(\*(.+?)\*)|(\[(.+?)\]\((.+?)\))/g;
  let lastIndex = 0;
  let match;

  while ((match = regex.exec(text)) !== null) {
    // Text before match
    if (match.index > lastIndex) {
      nodes.push({ type: "text", text: text.slice(lastIndex, match.index) });
    }
    if (match[1]) {
      // Bold
      nodes.push({
        type: "text",
        text: match[2],
        marks: [{ type: "strong" }],
      });
    } else if (match[3]) {
      // Italic
      nodes.push({
        type: "text",
        text: match[4],
        marks: [{ type: "em" }],
      });
    } else if (match[5]) {
      // Link
      nodes.push({
        type: "text",
        text: match[6],
        marks: [{ type: "link", attrs: { href: match[7] } }],
      });
    }
    lastIndex = match.index + match[0].length;
  }

  if (lastIndex < text.length) {
    nodes.push({ type: "text", text: text.slice(lastIndex) });
  }

  return nodes.length > 0 ? nodes : [{ type: "text", text }];
}

// ---------------------------------------------------------------------------
// MCP Server
// ---------------------------------------------------------------------------
const server = new McpServer({
  name: "substack-enhanced-mcp",
  version: "1.0.0",
});

// ---- create_draft_post -----------------------------------------------------
server.tool(
  "create_draft_post",
  "Create a new draft post on Substack. Returns the draft ID which can be used to publish it.",
  {
    title: z.string().describe("Post title"),
    subtitle: z.string().optional().describe("Post subtitle"),
    body: z.string().describe("Post body (supports Markdown-ish: # headings, **bold**, *italic*, [links](url), - bullets, 1. numbered, --- hr)"),
    audience: z
      .enum(["everyone", "only_paid", "founding", "only_free"])
      .optional()
      .default("everyone")
      .describe("Who can see the post"),
  },
  async ({ title, subtitle, body, audience }) => {
    const doc = textToDoc(body);
    const payload = {
      draft_title: title,
      draft_subtitle: subtitle || "",
      draft_body: JSON.stringify(doc),
      draft_bylines: [{ id: parseInt(USER_ID), is_guest: false }],
      audience: audience || "everyone",
      section_chosen: false,
      draft_section_id: null,
      write_comment_permissions: "everyone",
    };
    const result = await api("POST", "/drafts", payload);
    return {
      content: [
        {
          type: "text",
          text: JSON.stringify(
            {
              status: "draft_created",
              id: result.id,
              title: result.draft_title,
              edit_url: `${PUBLICATION_URL}/publish/post/${result.id}`,
              message:
                "Draft created. Use publish_draft with this ID to publish it, or edit it in the Substack dashboard.",
            },
            null,
            2
          ),
        },
      ],
    };
  }
);

// ---- publish_draft ---------------------------------------------------------
server.tool(
  "publish_draft",
  "Publish an existing Substack draft, making it live. Optionally send as email to subscribers.",
  {
    draft_id: z.union([z.string(), z.number()]).describe("The draft ID to publish (from create_draft_post or list_drafts)"),
    send_email: z.boolean().optional().default(true).describe("Send the post as an email to subscribers (default: true)"),
  },
  async ({ draft_id, send_email }) => {
    // First, make the draft publishable by setting it to ready
    const publishPayload = {
      send: send_email !== false,
    };
    const result = await api(
      "POST",
      `/drafts/${draft_id}/publish`,
      publishPayload
    );
    return {
      content: [
        {
          type: "text",
          text: JSON.stringify(
            {
              status: "published",
              id: draft_id,
              url: result.canonical_url || result.url || `Published draft ${draft_id}`,
              email_sent: send_email !== false,
              message: "Post is now live!",
            },
            null,
            2
          ),
        },
      ],
    };
  }
);

// ---- list_drafts -----------------------------------------------------------
server.tool(
  "list_drafts",
  "List all draft posts in your Substack publication.",
  {
    limit: z.number().optional().default(25).describe("Max drafts to return (default 25)"),
    offset: z.number().optional().default(0).describe("Pagination offset"),
  },
  async ({ limit, offset }) => {
    const params = new URLSearchParams({
      limit: String(limit || 25),
      offset: String(offset || 0),
      order_by: "draft_updated_at",
      order_direction: "desc",
    });
    const result = await api(
      "GET",
      `/post_management/drafts?${params.toString()}`
    );
    const drafts = Array.isArray(result) ? result : result.posts || result.drafts || [];
    const summary = drafts.map((d) => ({
      id: d.id,
      title: d.draft_title || d.title,
      subtitle: d.draft_subtitle || d.subtitle || "",
      updated_at: d.draft_updated_at || d.updated_at,
      audience: d.audience,
      edit_url: `${PUBLICATION_URL}/publish/post/${d.id}`,
    }));
    return {
      content: [
        {
          type: "text",
          text: JSON.stringify(
            { count: summary.length, drafts: summary },
            null,
            2
          ),
        },
      ],
    };
  }
);

// ---- list_posts ------------------------------------------------------------
server.tool(
  "list_posts",
  "List published posts in your Substack publication.",
  {
    limit: z.number().optional().default(10).describe("Max posts to return (default 10, max 50)"),
    offset: z.number().optional().default(0).describe("Pagination offset"),
  },
  async ({ limit, offset }) => {
    const params = new URLSearchParams({
      limit: String(Math.min(limit || 10, 50)),
      offset: String(offset || 0),
    });
    const result = await api("GET", `/posts?${params.toString()}`);
    const posts = Array.isArray(result) ? result : result.posts || [];
    const summary = posts.map((p) => ({
      id: p.id,
      title: p.title,
      subtitle: p.subtitle || "",
      slug: p.slug,
      url: p.canonical_url || `${PUBLICATION_URL}/p/${p.slug}`,
      publish_date: p.post_date || p.publish_date,
      audience: p.audience,
      likes: p.reactions?.["\u2764"] || p.like_count || 0,
      comments: p.comment_count || 0,
    }));
    return {
      content: [
        {
          type: "text",
          text: JSON.stringify(
            { count: summary.length, posts: summary },
            null,
            2
          ),
        },
      ],
    };
  }
);

// ---- get_post --------------------------------------------------------------
server.tool(
  "get_post",
  "Get details of a specific Substack post or draft by its ID.",
  {
    post_id: z.union([z.string(), z.number()]).describe("The post or draft ID"),
  },
  async ({ post_id }) => {
    // Try draft endpoint first, fall back to posts
    let result;
    try {
      result = await api("GET", `/drafts/${post_id}`);
    } catch {
      result = await api("GET", `/posts/${post_id}`);
    }
    return {
      content: [
        {
          type: "text",
          text: JSON.stringify(
            {
              id: result.id,
              title: result.draft_title || result.title,
              subtitle: result.draft_subtitle || result.subtitle || "",
              audience: result.audience,
              status: result.draft_title ? "draft" : "published",
              url:
                result.canonical_url ||
                (result.slug
                  ? `${PUBLICATION_URL}/p/${result.slug}`
                  : `${PUBLICATION_URL}/publish/post/${result.id}`),
              created_at: result.draft_created_at || result.post_date,
              updated_at: result.draft_updated_at || result.updated_at,
              word_count: result.word_count,
              likes: result.reactions?.["\u2764"] || result.like_count || 0,
              comments: result.comment_count || 0,
            },
            null,
            2
          ),
        },
      ],
    };
  }
);

// ---- delete_draft ----------------------------------------------------------
server.tool(
  "delete_draft",
  "Delete a draft post from your Substack publication. This cannot be undone.",
  {
    draft_id: z.union([z.string(), z.number()]).describe("The draft ID to delete"),
  },
  async ({ draft_id }) => {
    await api("DELETE", `/drafts/${draft_id}`);
    return {
      content: [
        {
          type: "text",
          text: JSON.stringify(
            {
              status: "deleted",
              id: draft_id,
              message: "Draft has been permanently deleted.",
            },
            null,
            2
          ),
        },
      ],
    };
  }
);

// ---------------------------------------------------------------------------
// Start
// ---------------------------------------------------------------------------
const transport = new StdioServerTransport();
await server.connect(transport);
