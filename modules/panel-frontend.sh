#!/bin/bash

# Panel Frontend Installation Module
# Sets up Next.js-based web interface for server panel

source "$(dirname "$0")/helper.sh" 2>/dev/null || true

# Panel configuration
PANEL_DIR="/opt/server-panel/panel"
PANEL_FRONTEND_DIR="$PANEL_DIR/frontend"
PANEL_DOMAIN=""
NODE_VERSION="18"

install_panel_frontend() {
    local domain="$1"
    
    if [[ -z "$domain" ]]; then
        log "ERROR" "Domain is required for panel frontend installation"
        return 1
    fi
    
    PANEL_DOMAIN="$domain"
    
    log "INFO" "Installing Panel Frontend for $domain"
    
    # Install Node.js
    install_nodejs
    
    # Create panel directories
    setup_panel_directories
    
    # Create Next.js application
    create_nextjs_app
    
    # Create panel components
    create_panel_components
    
    # Create Docker configuration
    create_frontend_docker_config
    
    # Build and deploy
    build_and_deploy_frontend
    
    log "SUCCESS" "Panel Frontend installation completed"
}

install_nodejs() {
    log "INFO" "Installing Node.js $NODE_VERSION"
    
    # Check if Node.js is already installed with correct version
    if command -v node &>/dev/null; then
        local current_version
        current_version=$(node --version | cut -d'v' -f2 | cut -d'.' -f1)
        if [[ "$current_version" -ge "$NODE_VERSION" ]]; then
            log "INFO" "Node.js $current_version is already installed"
            return 0
        fi
    fi
    
    # Install Node.js using NodeSource repository
    curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | bash -
    install_package nodejs
    
    # Install npm if not available
    if ! command -v npm &>/dev/null; then
        install_package npm
    fi
    
    # Verify installation
    if command -v node &>/dev/null && command -v npm &>/dev/null; then
        local node_version npm_version
        node_version=$(node --version)
        npm_version=$(npm --version)
        log "SUCCESS" "Node.js installed: $node_version, npm: $npm_version"
    else
        log "ERROR" "Failed to install Node.js"
        return 1
    fi
}

setup_panel_directories() {
    log "INFO" "Setting up panel directories"
    
    create_directory "$PANEL_DIR" "root" "root" "755"
    create_directory "$PANEL_FRONTEND_DIR" "root" "root" "755"
    
    log "SUCCESS" "Panel directories created"
}

create_nextjs_app() {
    log "INFO" "Creating Next.js application"
    
    cd "$PANEL_DIR"
    
    # Create package.json
    cat > "$PANEL_FRONTEND_DIR/package.json" << 'EOF'
{
  "name": "server-panel-frontend",
  "version": "1.0.0",
  "description": "Server Panel Frontend - cPanel-like web interface",
  "private": true,
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "start": "next start",
    "lint": "next lint",
    "export": "next export"
  },
  "dependencies": {
    "next": "14.0.0",
    "react": "18.2.0",
    "react-dom": "18.2.0",
    "@tailwindcss/forms": "^0.5.6",
    "tailwindcss": "^3.3.5",
    "autoprefixer": "^10.4.16",
    "postcss": "^8.4.31",
    "axios": "^1.5.1",
    "react-query": "^3.39.3",
    "react-hook-form": "^7.47.0",
    "react-hot-toast": "^2.4.1",
    "lucide-react": "^0.292.0",
    "js-cookie": "^3.0.5",
    "chart.js": "^4.4.0",
    "react-chartjs-2": "^5.2.0",
    "date-fns": "^2.30.0",
    "clsx": "^2.0.0"
  },
  "devDependencies": {
    "@types/node": "20.8.7",
    "@types/react": "18.2.33",
    "@types/react-dom": "18.2.14",
    "@types/js-cookie": "^3.0.6",
    "typescript": "5.2.2",
    "eslint": "8.52.0",
    "eslint-config-next": "14.0.0"
  }
}
EOF
    
    # Create Next.js config
    cat > "$PANEL_FRONTEND_DIR/next.config.js" << 'EOF'
/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  swcMinify: true,
  images: {
    unoptimized: true
  },
  env: {
    NEXT_PUBLIC_API_URL: process.env.NEXT_PUBLIC_API_URL || 'http://localhost:3001',
    NEXT_PUBLIC_PANEL_DOMAIN: process.env.NEXT_PUBLIC_PANEL_DOMAIN || 'localhost'
  },
  async rewrites() {
    return [
      {
        source: '/api/:path*',
        destination: `${process.env.NEXT_PUBLIC_API_URL}/api/:path*`
      }
    ]
  }
}

module.exports = nextConfig
EOF
    
    # Create TypeScript config
    cat > "$PANEL_FRONTEND_DIR/tsconfig.json" << 'EOF'
{
  "compilerOptions": {
    "target": "es5",
    "lib": ["dom", "dom.iterable", "esnext"],
    "allowJs": true,
    "skipLibCheck": true,
    "strict": true,
    "forceConsistentCasingInFileNames": true,
    "noEmit": true,
    "esModuleInterop": true,
    "module": "esnext",
    "moduleResolution": "node",
    "resolveJsonModule": true,
    "isolatedModules": true,
    "jsx": "preserve",
    "incremental": true,
    "plugins": [
      {
        "name": "next"
      }
    ],
    "baseUrl": ".",
    "paths": {
      "@/*": ["./*"],
      "@/components/*": ["./components/*"],
      "@/pages/*": ["./pages/*"],
      "@/styles/*": ["./styles/*"],
      "@/lib/*": ["./lib/*"],
      "@/types/*": ["./types/*"]
    }
  },
  "include": ["next-env.d.ts", "**/*.ts", "**/*.tsx", ".next/types/**/*.ts"],
  "exclude": ["node_modules"]
}
EOF
    
    # Create Tailwind CSS config
    cat > "$PANEL_FRONTEND_DIR/tailwind.config.js" << 'EOF'
/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    './pages/**/*.{js,ts,jsx,tsx,mdx}',
    './components/**/*.{js,ts,jsx,tsx,mdx}',
    './app/**/*.{js,ts,jsx,tsx,mdx}',
  ],
  theme: {
    extend: {
      colors: {
        primary: {
          50: '#eff6ff',
          100: '#dbeafe',
          200: '#bfdbfe',
          300: '#93c5fd',
          400: '#60a5fa',
          500: '#3b82f6',
          600: '#2563eb',
          700: '#1d4ed8',
          800: '#1e40af',
          900: '#1e3a8a',
        },
        panel: {
          50: '#f8fafc',
          100: '#f1f5f9',
          200: '#e2e8f0',
          300: '#cbd5e1',
          400: '#94a3b8',
          500: '#64748b',
          600: '#475569',
          700: '#334155',
          800: '#1e293b',
          900: '#0f172a',
        }
      }
    },
  },
  plugins: [
    require('@tailwindcss/forms'),
  ],
}
EOF
    
    # Create PostCSS config
    cat > "$PANEL_FRONTEND_DIR/postcss.config.js" << 'EOF'
module.exports = {
  plugins: {
    tailwindcss: {},
    autoprefixer: {},
  },
}
EOF
    
    log "SUCCESS" "Next.js application structure created"
}

create_panel_components() {
    log "INFO" "Creating panel components and pages"
    
    # Create directory structure
    mkdir -p "$PANEL_FRONTEND_DIR"/{pages,components,lib,types,styles,public}
    mkdir -p "$PANEL_FRONTEND_DIR/components"/{layout,ui,forms}
    mkdir -p "$PANEL_FRONTEND_DIR/pages"/{api,dashboard,apps,files,settings}
    
    # Create global styles
    cat > "$PANEL_FRONTEND_DIR/styles/globals.css" << 'EOF'
@tailwind base;
@tailwind components;
@tailwind utilities;

@layer base {
  html {
    font-family: 'Inter', system-ui, sans-serif;
  }
  
  body {
    @apply bg-panel-50 text-panel-900;
  }
}

@layer components {
  .btn {
    @apply px-4 py-2 rounded-lg font-medium transition-colors focus:outline-none focus:ring-2 focus:ring-offset-2;
  }
  
  .btn-primary {
    @apply btn bg-primary-600 text-white hover:bg-primary-700 focus:ring-primary-500;
  }
  
  .btn-secondary {
    @apply btn bg-panel-200 text-panel-900 hover:bg-panel-300 focus:ring-panel-500;
  }
  
  .card {
    @apply bg-white rounded-lg shadow-sm border border-panel-200 p-6;
  }
  
  .input {
    @apply block w-full rounded-lg border-panel-300 shadow-sm focus:border-primary-500 focus:ring-primary-500;
  }
}
EOF
    
    # Create main layout component
    cat > "$PANEL_FRONTEND_DIR/components/layout/Layout.tsx" << 'EOF'
import React from 'react'
import { useRouter } from 'next/router'
import Sidebar from './Sidebar'
import Header from './Header'
import { useAuth } from '@/lib/auth'

interface LayoutProps {
  children: React.ReactNode
}

export default function Layout({ children }: LayoutProps) {
  const router = useRouter()
  const { user, loading } = useAuth()
  
  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <div className="animate-spin rounded-full h-32 w-32 border-b-2 border-primary-600"></div>
      </div>
    )
  }
  
  if (!user && router.pathname !== '/login') {
    router.push('/login')
    return null
  }
  
  if (router.pathname === '/login') {
    return <>{children}</>
  }
  
  return (
    <div className="min-h-screen bg-panel-50">
      <Sidebar />
      <div className="pl-64">
        <Header />
        <main className="p-6">
          {children}
        </main>
      </div>
    </div>
  )
}
EOF
    
    # Create sidebar component
    cat > "$PANEL_FRONTEND_DIR/components/layout/Sidebar.tsx" << 'EOF'
import React from 'react'
import Link from 'next/link'
import { useRouter } from 'next/router'
import {
  HomeIcon,
  ServerIcon,
  FolderIcon,
  CogIcon,
  DatabaseIcon,
  ShieldCheckIcon,
  ChartBarIcon,
  UserGroupIcon
} from 'lucide-react'

const navigation = [
  { name: 'Dashboard', href: '/dashboard', icon: HomeIcon },
  { name: 'Applications', href: '/apps', icon: ServerIcon },
  { name: 'File Manager', href: '/files', icon: FolderIcon },
  { name: 'Databases', href: '/databases', icon: DatabaseIcon },
  { name: 'SSL Certificates', href: '/ssl', icon: ShieldCheckIcon },
  { name: 'Analytics', href: '/analytics', icon: ChartBarIcon },
  { name: 'Users', href: '/users', icon: UserGroupIcon },
  { name: 'Settings', href: '/settings', icon: CogIcon },
]

export default function Sidebar() {
  const router = useRouter()
  
  return (
    <div className="fixed inset-y-0 left-0 z-50 w-64 bg-panel-900 text-white">
      <div className="flex h-16 items-center px-6">
        <h1 className="text-xl font-bold">Server Panel</h1>
      </div>
      
      <nav className="mt-6 px-3">
        <ul className="space-y-1">
          {navigation.map((item) => {
            const isActive = router.pathname.startsWith(item.href)
            return (
              <li key={item.name}>
                <Link
                  href={item.href}
                  className={`
                    flex items-center px-3 py-2 rounded-lg text-sm font-medium transition-colors
                    ${isActive 
                      ? 'bg-primary-600 text-white' 
                      : 'text-panel-300 hover:bg-panel-800 hover:text-white'
                    }
                  `}
                >
                  <item.icon className="mr-3 h-5 w-5" />
                  {item.name}
                </Link>
              </li>
            )
          })}
        </ul>
      </nav>
    </div>
  )
}
EOF
    
    # Create header component
    cat > "$PANEL_FRONTEND_DIR/components/layout/Header.tsx" << 'EOF'
import React from 'react'
import { useAuth } from '@/lib/auth'
import { LogOutIcon, UserIcon } from 'lucide-react'

export default function Header() {
  const { user, logout } = useAuth()
  
  return (
    <header className="bg-white border-b border-panel-200 h-16 flex items-center justify-between px-6">
      <div className="flex items-center">
        <h2 className="text-lg font-semibold text-panel-900">
          Welcome back, {user?.name || 'Admin'}
        </h2>
      </div>
      
      <div className="flex items-center space-x-4">
        <div className="flex items-center space-x-2 text-sm text-panel-600">
          <UserIcon className="h-4 w-4" />
          <span>{user?.email}</span>
        </div>
        
        <button
          onClick={logout}
          className="flex items-center space-x-2 px-3 py-2 text-sm text-panel-600 hover:text-panel-900 transition-colors"
        >
          <LogOutIcon className="h-4 w-4" />
          <span>Logout</span>
        </button>
      </div>
    </header>
  )
}
EOF
    
    # Create main pages
    cat > "$PANEL_FRONTEND_DIR/pages/_app.tsx" << 'EOF'
import type { AppProps } from 'next/app'
import { QueryClient, QueryClientProvider } from 'react-query'
import { Toaster } from 'react-hot-toast'
import Layout from '@/components/layout/Layout'
import { AuthProvider } from '@/lib/auth'
import '@/styles/globals.css'

const queryClient = new QueryClient()

export default function App({ Component, pageProps }: AppProps) {
  return (
    <QueryClientProvider client={queryClient}>
      <AuthProvider>
        <Layout>
          <Component {...pageProps} />
        </Layout>
        <Toaster position="top-right" />
      </AuthProvider>
    </QueryClientProvider>
  )
}
EOF
    
    # Create dashboard page
    cat > "$PANEL_FRONTEND_DIR/pages/dashboard/index.tsx" << 'EOF'
import React from 'react'
import { useQuery } from 'react-query'
import { api } from '@/lib/api'
import { ServerIcon, DatabaseIcon, ShieldCheckIcon, UsersIcon } from 'lucide-react'

interface DashboardStats {
  apps: number
  databases: number
  ssl_certificates: number
  users: number
  disk_usage: number
  memory_usage: number
  cpu_usage: number
}

export default function Dashboard() {
  const { data: stats, isLoading } = useQuery<DashboardStats>('dashboard-stats', () =>
    api.get('/dashboard/stats').then(res => res.data)
  )
  
  if (isLoading) {
    return <div>Loading dashboard...</div>
  }
  
  const statsCards = [
    { name: 'Applications', value: stats?.apps || 0, icon: ServerIcon, color: 'bg-blue-500' },
    { name: 'Databases', value: stats?.databases || 0, icon: DatabaseIcon, color: 'bg-green-500' },
    { name: 'SSL Certificates', value: stats?.ssl_certificates || 0, icon: ShieldCheckIcon, color: 'bg-yellow-500' },
    { name: 'Users', value: stats?.users || 0, icon: UsersIcon, color: 'bg-purple-500' },
  ]
  
  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-panel-900">Dashboard</h1>
        <p className="text-panel-600">Overview of your server panel</p>
      </div>
      
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        {statsCards.map((stat) => (
          <div key={stat.name} className="card">
            <div className="flex items-center">
              <div className={`p-3 rounded-lg ${stat.color}`}>
                <stat.icon className="h-6 w-6 text-white" />
              </div>
              <div className="ml-4">
                <p className="text-sm font-medium text-panel-600">{stat.name}</p>
                <p className="text-2xl font-bold text-panel-900">{stat.value}</p>
              </div>
            </div>
          </div>
        ))}
      </div>
      
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <div className="card">
          <h3 className="text-lg font-medium text-panel-900 mb-4">System Resources</h3>
          <div className="space-y-4">
            <div>
              <div className="flex justify-between text-sm">
                <span>CPU Usage</span>
                <span>{stats?.cpu_usage || 0}%</span>
              </div>
              <div className="w-full bg-panel-200 rounded-full h-2">
                <div
                  className="bg-blue-600 h-2 rounded-full"
                  style={{ width: `${stats?.cpu_usage || 0}%` }}
                ></div>
              </div>
            </div>
            
            <div>
              <div className="flex justify-between text-sm">
                <span>Memory Usage</span>
                <span>{stats?.memory_usage || 0}%</span>
              </div>
              <div className="w-full bg-panel-200 rounded-full h-2">
                <div
                  className="bg-green-600 h-2 rounded-full"
                  style={{ width: `${stats?.memory_usage || 0}%` }}
                ></div>
              </div>
            </div>
            
            <div>
              <div className="flex justify-between text-sm">
                <span>Disk Usage</span>
                <span>{stats?.disk_usage || 0}%</span>
              </div>
              <div className="w-full bg-panel-200 rounded-full h-2">
                <div
                  className="bg-yellow-600 h-2 rounded-full"
                  style={{ width: `${stats?.disk_usage || 0}%` }}
                ></div>
              </div>
            </div>
          </div>
        </div>
        
        <div className="card">
          <h3 className="text-lg font-medium text-panel-900 mb-4">Quick Actions</h3>
          <div className="grid grid-cols-2 gap-4">
            <button className="btn-primary">Deploy App</button>
            <button className="btn-secondary">Create Database</button>
            <button className="btn-secondary">Add SSL</button>
            <button className="btn-secondary">Manage Files</button>
          </div>
        </div>
      </div>
    </div>
  )
}
EOF
    
    # Create login page
    cat > "$PANEL_FRONTEND_DIR/pages/login.tsx" << 'EOF'
import React, { useState } from 'react'
import { useRouter } from 'next/router'
import { useForm } from 'react-hook-form'
import toast from 'react-hot-toast'
import { useAuth } from '@/lib/auth'

interface LoginForm {
  email: string
  password: string
}

export default function Login() {
  const router = useRouter()
  const { login } = useAuth()
  const [loading, setLoading] = useState(false)
  
  const { register, handleSubmit, formState: { errors } } = useForm<LoginForm>()
  
  const onSubmit = async (data: LoginForm) => {
    setLoading(true)
    try {
      await login(data.email, data.password)
      toast.success('Login successful!')
      router.push('/dashboard')
    } catch (error) {
      toast.error('Login failed. Please check your credentials.')
    } finally {
      setLoading(false)
    }
  }
  
  return (
    <div className="min-h-screen flex items-center justify-center bg-panel-50 py-12 px-4 sm:px-6 lg:px-8">
      <div className="max-w-md w-full space-y-8">
        <div>
          <h1 className="text-center text-3xl font-extrabold text-panel-900">
            Server Panel
          </h1>
          <h2 className="mt-6 text-center text-2xl font-bold text-panel-900">
            Sign in to your account
          </h2>
        </div>
        
        <form className="mt-8 space-y-6" onSubmit={handleSubmit(onSubmit)}>
          <div className="space-y-4">
            <div>
              <label htmlFor="email" className="block text-sm font-medium text-panel-700">
                Email address
              </label>
              <input
                {...register('email', { required: 'Email is required' })}
                type="email"
                className="input mt-1"
                placeholder="Enter your email"
              />
              {errors.email && (
                <p className="mt-1 text-sm text-red-600">{errors.email.message}</p>
              )}
            </div>
            
            <div>
              <label htmlFor="password" className="block text-sm font-medium text-panel-700">
                Password
              </label>
              <input
                {...register('password', { required: 'Password is required' })}
                type="password"
                className="input mt-1"
                placeholder="Enter your password"
              />
              {errors.password && (
                <p className="mt-1 text-sm text-red-600">{errors.password.message}</p>
              )}
            </div>
          </div>
          
          <button
            type="submit"
            disabled={loading}
            className="btn-primary w-full"
          >
            {loading ? 'Signing in...' : 'Sign in'}
          </button>
        </form>
      </div>
    </div>
  )
}
EOF
    
    # Create authentication hook
    cat > "$PANEL_FRONTEND_DIR/lib/auth.tsx" << 'EOF'
import React, { createContext, useContext, useState, useEffect } from 'react'
import { api } from './api'
import Cookies from 'js-cookie'

interface User {
  id: string
  email: string
  name: string
  role: string
}

interface AuthContextType {
  user: User | null
  loading: boolean
  login: (email: string, password: string) => Promise<void>
  logout: () => void
}

const AuthContext = createContext<AuthContextType | undefined>(undefined)

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [user, setUser] = useState<User | null>(null)
  const [loading, setLoading] = useState(true)
  
  useEffect(() => {
    const token = Cookies.get('auth-token')
    if (token) {
      fetchUser()
    } else {
      setLoading(false)
    }
  }, [])
  
  const fetchUser = async () => {
    try {
      const response = await api.get('/auth/me')
      setUser(response.data.user)
    } catch (error) {
      Cookies.remove('auth-token')
    } finally {
      setLoading(false)
    }
  }
  
  const login = async (email: string, password: string) => {
    const response = await api.post('/auth/login', { email, password })
    const { token, user } = response.data
    
    Cookies.set('auth-token', token, { expires: 7 })
    setUser(user)
  }
  
  const logout = () => {
    Cookies.remove('auth-token')
    setUser(null)
  }
  
  return (
    <AuthContext.Provider value={{ user, loading, login, logout }}>
      {children}
    </AuthContext.Provider>
  )
}

export function useAuth() {
  const context = useContext(AuthContext)
  if (context === undefined) {
    throw new Error('useAuth must be used within an AuthProvider')
  }
  return context
}
EOF
    
    # Create API utility
    cat > "$PANEL_FRONTEND_DIR/lib/api.ts" << 'EOF'
import axios from 'axios'
import Cookies from 'js-cookie'

export const api = axios.create({
  baseURL: process.env.NEXT_PUBLIC_API_URL || 'http://localhost:3001',
  timeout: 10000,
})

api.interceptors.request.use((config) => {
  const token = Cookies.get('auth-token')
  if (token) {
    config.headers.Authorization = `Bearer ${token}`
  }
  return config
})

api.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error.response?.status === 401) {
      Cookies.remove('auth-token')
      window.location.href = '/login'
    }
    return Promise.reject(error)
  }
)
EOF
    
    log "SUCCESS" "Panel components and pages created"
}

create_frontend_docker_config() {
    log "INFO" "Creating frontend Docker configuration"
    
    # Create Dockerfile for frontend
    cat > "$PANEL_FRONTEND_DIR/Dockerfile" << 'EOF'
FROM node:18-alpine AS base

# Install dependencies only when needed
FROM base AS deps
RUN apk add --no-cache libc6-compat
WORKDIR /app

# Install dependencies based on the preferred package manager
COPY package.json package-lock.json* ./
RUN npm ci --only=production

# Rebuild the source code only when needed
FROM base AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .

# Build the application
RUN npm run build

# Production image, copy all the files and run next
FROM base AS runner
WORKDIR /app

ENV NODE_ENV production

RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs

COPY --from=builder /app/public ./public

# Automatically leverage output traces to reduce image size
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

USER nextjs

EXPOSE 3000

ENV PORT 3000
ENV HOSTNAME "0.0.0.0"

CMD ["node", "server.js"]
EOF
    
    # Create docker-compose for frontend
    cat > "$PANEL_FRONTEND_DIR/docker-compose.yml" << EOF
version: '3.8'

services:
  frontend:
    build: .
    container_name: server-panel-frontend
    restart: unless-stopped
    networks:
      - server-panel
    ports:
      - "127.0.0.1:3000:3000"
    environment:
      - NODE_ENV=production
      - NEXT_PUBLIC_API_URL=http://127.0.0.1:3001
      - NEXT_PUBLIC_PANEL_DOMAIN=$PANEL_DOMAIN
    volumes:
      - ./.env.local:/app/.env.local:ro
    depends_on:
      - backend

  backend:
    image: server-panel-backend:latest
    container_name: server-panel-backend
    restart: unless-stopped
    networks:
      - server-panel
    ports:
      - "127.0.0.1:3001:3001"
    environment:
      - NODE_ENV=production
    volumes:
      - /var/server-panel:/app/data

networks:
  server-panel:
    external: true
EOF
    
    # Create environment file
    cat > "$PANEL_FRONTEND_DIR/.env.local" << EOF
NEXT_PUBLIC_API_URL=http://127.0.0.1:3001
NEXT_PUBLIC_PANEL_DOMAIN=$PANEL_DOMAIN
NODE_ENV=production
EOF
    
    log "SUCCESS" "Frontend Docker configuration created"
}

build_and_deploy_frontend() {
    log "INFO" "Building and deploying frontend"
    
    cd "$PANEL_FRONTEND_DIR"
    
    # Install dependencies
    npm install
    
    if [[ $? -ne 0 ]]; then
        log "ERROR" "Failed to install frontend dependencies"
        return 1
    fi
    
    # Build the application
    npm run build
    
    if [[ $? -ne 0 ]]; then
        log "ERROR" "Failed to build frontend application"
        return 1
    fi
    
    # Build Docker image
    docker build -t server-panel-frontend:latest .
    
    if [[ $? -eq 0 ]]; then
        log "SUCCESS" "Frontend Docker image built successfully"
    else
        log "ERROR" "Failed to build frontend Docker image"
        return 1
    fi
    
    log "SUCCESS" "Frontend built and deployed successfully"
}

# Main execution
main() {
    case "${1:-install}" in
        "install")
            install_panel_frontend "$2"
            ;;
        "build")
            build_and_deploy_frontend
            ;;
        *)
            echo "Usage: $0 [install|build] [domain]"
            exit 1
            ;;
    esac
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 