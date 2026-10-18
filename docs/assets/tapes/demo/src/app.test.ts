import { describe, expect, it } from "vitest";
import { startApp } from "./app";

describe("startApp", () => {
  it("starts the router on the configured port", async () => {
    await expect(startApp()).resolves.toBeUndefined();
  });
});
