module ApplicationHelper
  # One source of truth for status colors. `color` and `glyph` are handed to the map markers;
  # the Tailwind classes are written out in full so the class scanner sees them.
  STATUS_STYLES = {
    "prepared"         => { color: "#64748b", glyph: "P", badge: "bg-slate-100 text-slate-700 ring-slate-500/20",       dot: "bg-slate-500" },
    "picked_up"        => { color: "#0ea5e9", glyph: "↑", badge: "bg-sky-50 text-sky-700 ring-sky-600/20",               dot: "bg-sky-500" },
    "in_transit"       => { color: "#6366f1", glyph: "→", badge: "bg-indigo-50 text-indigo-700 ring-indigo-600/20",      dot: "bg-indigo-500" },
    "out_for_delivery" => { color: "#f59e0b", glyph: "⌂", badge: "bg-amber-50 text-amber-800 ring-amber-600/20",         dot: "bg-amber-500" },
    "delivered"        => { color: "#10b981", glyph: "✓", badge: "bg-emerald-50 text-emerald-700 ring-emerald-600/20",   dot: "bg-emerald-500" },
    "exception"        => { color: "#ef4444", glyph: "!", badge: "bg-red-50 text-red-700 ring-red-600/20",               dot: "bg-red-500" }
  }.freeze

  def status_style(status)
    STATUS_STYLES.fetch(status.to_s)
  end

  def status_label(status)
    status.to_s.humanize
  end

  # Times are shown in UTC everywhere (server views and map info windows).
  def format_time(time)
    "#{l(time.utc, format: :long)} UTC"
  end

  def status_badge(status)
    style = status_style(status)
    tag.span(class: "inline-flex items-center gap-1.5 rounded-full px-2.5 py-0.5 text-xs font-medium ring-1 ring-inset #{style[:badge]}") do
      tag.span(class: "size-1.5 rounded-full #{style[:dot]}") + status_label(status)
    end
  end
end
