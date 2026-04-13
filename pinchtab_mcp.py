import asyncio
import httpx
import json
from mcp.server.fastmcp import FastMCP

# Initialize FastMCP
mcp = FastMCP("Pinch Tab")

BASE_URL = "http://localhost:9867"

@mcp.tool()
async def list_profiles():
    """List all available browser profiles in Pinch Tab."""
    async with httpx.AsyncClient() as client:
        response = await client.get(f"{BASE_URL}/profiles")
        return response.json()

@mcp.tool()
async def navigate_tab(profile: str, url: str):
    """Navigate a browser tab in the specified profile to a URL."""
    async with httpx.AsyncClient() as client:
        response = await client.post(
            f"{BASE_URL}/navigate",
            params={"profile": profile},
            json={"url": url}
        )
        return response.json()

@mcp.tool()
async def get_snapshot(profile: str):
    """Get an AI-optimized snapshot (accessibility tree) of the current page."""
    async with httpx.AsyncClient() as client:
        response = await client.get(
            f"{BASE_URL}/snapshot",
            params={"profile": profile, "format": "ai"}
        )
        return response.json()

@mcp.tool()
async def take_screenshot(profile: str):
    """Capture a screenshot of the current page in the specified profile."""
    async with httpx.AsyncClient() as client:
        response = await client.post(
            f"{BASE_URL}/screenshot",
            params={"profile": profile},
            json={}
        )
        return response.json()

@mcp.tool()
async def perform_action(profile: str, kind: str, ref: str = None, text: str = None, key: str = None, direction: str = None):
    """
    Perform an action on the page.
    Kinds: click, type, press, scroll
    - For 'click': provide 'ref'
    - For 'type': provide 'ref' and 'text'
    - For 'press': provide 'key' (e.g. 'Enter')
    - For 'scroll': provide 'direction' (up, down, left, right)
    """
    payload = {"kind": kind}
    if ref: payload["ref"] = ref
    if text: payload["text"] = text
    if key: payload["key"] = key
    if direction: payload["direction"] = direction
    
    async with httpx.AsyncClient() as client:
        response = await client.post(
            f"{BASE_URL}/act",
            params={"profile": profile},
            json=payload
        )
        return response.json()

if __name__ == "__main__":
    mcp.run()
