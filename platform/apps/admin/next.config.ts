import type { NextConfig } from 'next'

const nextConfig: NextConfig = {
  transpilePackages: ['@lumen/ui', '@lumen/types', '@lumen/supabase'],
  eslint: { ignoreDuringBuilds: true },
  images: {
    remotePatterns: [
      { protocol: 'https', hostname: '**.supabase.co', pathname: '/storage/v1/object/public/**' },
      { protocol: 'https', hostname: 'ui-avatars.com' },
    ],
  },
}

export default nextConfig
