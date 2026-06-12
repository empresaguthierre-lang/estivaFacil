module NavigationHelper
  def nav_link_to(label, path, icon:, active: request.path == path || (path != root_path && request.path.start_with?(path)))
    classes = [
      "inline-flex items-center gap-2 rounded-md px-3 py-2 text-sm font-medium transition-all duration-200 border",
      "focus:outline-none focus:ring-2 focus:ring-emerald-500/40 focus:ring-offset-2 focus:ring-offset-[#090D16]",
      active ? "bg-emerald-500/10 text-emerald-400 border-emerald-500/20 shadow-md shadow-emerald-950/20" : "text-slate-400 border-transparent hover:bg-slate-800/40 hover:border-slate-800/60 hover:text-slate-100"
    ].join(" ")

    link_to path, class: classes, "aria-current": (active ? "page" : nil) do
      safe_join([ lucide_icon(icon, css: "h-4 w-4"), tag.span(label) ])
    end
  end
end
