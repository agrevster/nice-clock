local ipaddr = http.fetch("https://api.ipify.org", http.methods.GET, nil, nil, nil).body
return niceclock
	.modulebuilder("IP module", 30, {}, {})
	:wrappedtext({ y = 0, x = 0 }, niceclock.fonts.Font5x8_2, ipaddr, { r = 64, g = 214, b = 45 }, 0)
