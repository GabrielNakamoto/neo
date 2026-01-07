const video = @import("./drivers/video.zig");
const keyboard = @import("./drivers/keyboard.zig");
const uart = @import("./uart.zig");
const uefi = @import("std").os.uefi;

var runtime_services: *uefi.tables.RuntimeServices = undefined;

pub fn initialize(rservices: *uefi.tables.RuntimeServices) void {
	runtime_services = rservices;
	keyboard.subscribers[0] = &video_subscriber;

	time, _ = rservices.getTime() catch unreachable;
}

var i: u8 = 0;
var time: uefi.Time = undefined;
var str: [32]u8 = [_]u8 {0} ** 32;
fn video_subscriber() void {
	if (keyboard.is_down(0x8) and i > 0) {
		i -= 1;
	}
	if (keyboard.is_clicked(' ')) {
		str[i]=' ';
		i += 1;
	}
	for ('A'..'Z'+1) |c|{
		const key: u8 = @truncate(c);
		if (keyboard.is_clicked(key)) {
			str[i]=key;
			i += 1;
		}
	}
}

pub fn periodic() void {
	str[i] = '_';
	video.fill_screen(0x0);
	video.printf("{d:0>2}:{d:0>2}:{d:0>2}> {s}", .{time.hour, time.minute, time.second, str[0..i+1]});
	video.render();
}
