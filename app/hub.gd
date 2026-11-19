class_name Hub
## Atlas hub addresses (SPEC §3): LAN primary, tailnet fallback. base_url is the winning base,
## set by main.gd's hub check, for the PTT chunk that follows.

const CANDIDATES := ["http://192.168.4.51:8765", "http://100.65.202.81:8765"]

static var base_url := ""
