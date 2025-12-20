#!/usr/bin/env python3
"""
Generate appcast.xml from GitHub Releases
Automatically fetches release information and converts markdown to HTML
"""

import json
import os
import sys
import re
from datetime import datetime
from typing import Dict, List, Optional
import urllib.request
import urllib.error
from xml.etree import ElementTree as ET
from xml.dom import minidom

def fetch_github_releases(repo: str, token: Optional[str] = None) -> List[Dict]:
    """Fetch releases from GitHub API"""
    url = f"https://api.github.com/repos/{repo}/releases"
    headers = {
        'Accept': 'application/vnd.github.v3+json',
        'User-Agent': 'XKey-Appcast-Generator'
    }
    
    if token:
        headers['Authorization'] = f'token {token}'
    
    req = urllib.request.Request(url, headers=headers)
    
    try:
        with urllib.request.urlopen(req) as response:
            return json.loads(response.read().decode())
    except urllib.error.HTTPError as e:
        print(f"Error fetching releases: {e}", file=sys.stderr)
        sys.exit(1)

def markdown_to_html(markdown: str) -> str:
    """Convert markdown to HTML (simple implementation)"""
    html = markdown
    
    # Headers
    html = re.sub(r'^### (.*?)$', r'<h3>\1</h3>', html, flags=re.MULTILINE)
    html = re.sub(r'^## (.*?)$', r'<h2>\1</h2>', html, flags=re.MULTILINE)
    html = re.sub(r'^# (.*?)$', r'<h1>\1</h1>', html, flags=re.MULTILINE)
    
    # Bold and italic
    html = re.sub(r'\*\*\*(.+?)\*\*\*', r'<strong><em>\1</em></strong>', html)
    html = re.sub(r'\*\*(.+?)\*\*', r'<strong>\1</strong>', html)
    html = re.sub(r'\*(.+?)\*', r'<em>\1</em>', html)
    html = re.sub(r'__(.+?)__', r'<strong>\1</strong>', html)
    html = re.sub(r'_(.+?)_', r'<em>\1</em>', html)
    
    # Links
    html = re.sub(r'\[(.+?)\]\((.+?)\)', r'<a href="\2">\1</a>', html)
    
    # Code blocks
    html = re.sub(r'```[\w]*\n(.*?)\n```', r'<pre><code>\1</code></pre>', html, flags=re.DOTALL)
    html = re.sub(r'`(.+?)`', r'<code>\1</code>', html)
    
    # Lists
    lines = html.split('\n')
    in_ul = False
    in_ol = False
    result = []
    
    for line in lines:
        # Unordered list
        if re.match(r'^[\*\-\+] ', line):
            if not in_ul:
                result.append('<ul>')
                in_ul = True
            result.append(f'<li>{line[2:].strip()}</li>')
        # Ordered list
        elif re.match(r'^\d+\. ', line):
            if not in_ol:
                result.append('<ol>')
                in_ol = True
            cleaned_line = re.sub(r'^\d+\. ', '', line).strip()
            result.append(f'<li>{cleaned_line}</li>')
        else:
            if in_ul:
                result.append('</ul>')
                in_ul = False
            if in_ol:
                result.append('</ol>')
                in_ol = False
            if line.strip():
                result.append(f'<p>{line}</p>')
    
    if in_ul:
        result.append('</ul>')
    if in_ol:
        result.append('</ol>')
    
    return '\n'.join(result)

def find_dmg_asset(assets: List[Dict]) -> Optional[Dict]:
    """Find the main DMG file in release assets"""
    # Look for XKey.dmg first
    for asset in assets:
        if asset['name'] == 'XKey.dmg':
            return asset
    
    # Fallback to any .dmg file
    for asset in assets:
        if asset['name'].endswith('.dmg') and 'IM' not in asset['name']:
            return asset
    
    return None

def format_rfc822_date(iso_date: str) -> str:
    """Convert ISO 8601 date to RFC 822 format"""
    dt = datetime.fromisoformat(iso_date.replace('Z', '+00:00'))
    return dt.strftime('%a, %d %b %Y %H:%M:%S %z')

def generate_appcast_xml(repo: str, token: Optional[str] = None) -> str:
    """Generate complete appcast.xml from GitHub releases"""
    releases = fetch_github_releases(repo, token)
    
    repo_owner = repo.split('/')[0]
    repo_name = repo.split('/')[1]
    
    # Start building XML manually to properly handle CDATA
    xml_lines = [
        '<?xml version="1.0" encoding="utf-8"?>',
        '<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" xmlns:dc="http://purl.org/dc/elements/1.1/">',
        '  <channel>',
        '    <title>XKey Updates</title>',
        f'    <link>https://{repo_owner}.github.io/{repo_name}/appcast.xml</link>',
        '    <description>XKey - Vietnamese Input Method for macOS</description>',
        '    <language>vi</language>',
    ]
    
    # Process releases (only the latest one)
    items_added = 0
    for release in releases:
        # Skip drafts and pre-releases
        if release.get('draft') or release.get('prerelease'):
            continue
        
        # Find DMG asset
        dmg_asset = find_dmg_asset(release.get('assets', []))
        if not dmg_asset:
            print(f"Warning: No DMG found for release {release['tag_name']}", file=sys.stderr)
            continue
        
        # Extract version from tag (remove 'v' prefix if present)
        version = release['tag_name'].lstrip('v')
        
        # Convert release notes markdown to HTML
        release_notes = release.get('body', '')
        release_notes_html = markdown_to_html(release_notes) if release_notes else ''
        
        # Add link to full release notes
        release_url = release['html_url']
        if release_notes_html:
            release_notes_html += f'\n<p><a href="{release_url}">Xem chi tiết trên GitHub</a></p>'
        
        # Parse and format published date
        pub_date = release.get('published_at', release.get('created_at'))
        formatted_date = format_rfc822_date(pub_date)
        
        # Add item
        xml_lines.extend([
            '    <item>',
            f'      <title>Version {version}</title>',
            f'      <link>{release_url}</link>',
            f'      <sparkle:version>{version}</sparkle:version>',
            f'      <sparkle:shortVersionString>{version}</sparkle:shortVersionString>',
            f'      <description><![CDATA[',
            f'        {release_notes_html}',
            f'      ]]></description>',
            f'      <pubDate>{formatted_date}</pubDate>',
            f'      <sparkle:minimumSystemVersion>12.0</sparkle:minimumSystemVersion>',
            f'      <enclosure ',
            f'        url="{dmg_asset["browser_download_url"]}" ',
            f'        sparkle:version="{version}" ',
            f'        sparkle:shortVersionString="{version}" ',
            f'        length="{dmg_asset["size"]}" ',
            f'        type="application/octet-stream" />',
            '    </item>',
        ])
        
        items_added += 1
        # Only include the latest release
        break
    
    if items_added == 0:
        print("Warning: No valid releases found", file=sys.stderr)
    
    # Close XML
    xml_lines.extend([
        '  </channel>',
        '</rss>',
    ])
    
    return '\n'.join(xml_lines)

def main():
    # Get repository from environment or argument
    repo = os.getenv('GITHUB_REPOSITORY', 'xmannv/xkey')
    token = os.getenv('GITHUB_TOKEN')
    
    # Generate appcast XML
    appcast_xml = generate_appcast_xml(repo, token)
    
    # Write to file
    output_path = os.getenv('OUTPUT_PATH', 'appcast.xml')
    with open(output_path, 'w', encoding='utf-8') as f:
        f.write(appcast_xml)
    
    print(f"✅ Generated appcast.xml")
    print(f"📝 Output: {output_path}")

if __name__ == '__main__':
    main()
