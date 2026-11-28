import { describe, expect, it } from "vitest";
import { rateLimitSubject } from "../src/iplimit";

describe("rateLimitSubject", () => {
  it("keeps IPv4 addresses whole", () => {
    expect(rateLimitSubject("203.0.113.7")).toBe("203.0.113.7");
  });

  it("groups IPv6 addresses by /64", () => {
    expect(rateLimitSubject("2001:db8:abcd:12:1::5")).toBe("2001:db8:abcd:12::/64");
    expect(rateLimitSubject("2001:0DB8:abcd:0012:ffff:ffff:ffff:ffff")).toBe("2001:db8:abcd:12::/64");
    expect(rateLimitSubject("2001:db8::1")).toBe("2001:db8:0:0::/64");
  });
});
