#!/bin/bash

# Panel Backend Installation Script
# Creates and configures NestJS backend API server

set -euo pipefail

# Source helper functions
source "$(dirname "$0")/helper.sh"

# Configuration
BACKEND_DIR="/opt/server-panel/backend"
BACKEND_DATA_DIR="/var/server-panel/backend"
BACKEND_PORT="${BACKEND_PORT:-3001}"
NODE_VERSION="18"

# Install backend
install_backend() {
    log "INFO" "Starting Panel Backend installation"
    
    check_dependencies
    create_backend_structure
    create_package_files
    create_backend_core
    create_auth_system
    create_user_management
    create_app_management
    create_monitoring_system
    create_dns_management
    create_docker_config
    setup_database_schema
    install_dependencies
    build_backend
    
    log "SUCCESS" "Panel Backend installation completed"
}

# Check dependencies
check_dependencies() {
    log "INFO" "Checking backend dependencies"
    
    # Install Node.js if not present
    if ! command -v node &> /dev/null; then
        install_nodejs
    fi
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        log "ERROR" "Docker is required but not installed"
        exit 1
    fi
    
    log "SUCCESS" "Dependencies check completed"
}

# Install Node.js
install_nodejs() {
    log "INFO" "Installing Node.js $NODE_VERSION"
    
    curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | bash -
    apt-get install -y nodejs
    
    log "SUCCESS" "Node.js $NODE_VERSION installed"
}

# Create backend directory structure
create_backend_structure() {
    log "INFO" "Creating backend directory structure"
    
    create_directory "$BACKEND_DIR" "root" "root" "755"
    create_directory "$BACKEND_DATA_DIR" "root" "root" "755"
    create_directory "$BACKEND_DIR/src" "root" "root" "755"
    create_directory "$BACKEND_DIR/src/auth" "root" "root" "755"
    create_directory "$BACKEND_DIR/src/auth/dto" "root" "root" "755"
    create_directory "$BACKEND_DIR/src/auth/guards" "root" "root" "755"
    create_directory "$BACKEND_DIR/src/auth/strategies" "root" "root" "755"
    create_directory "$BACKEND_DIR/src/users" "root" "root" "755"
    create_directory "$BACKEND_DIR/src/users/dto" "root" "root" "755"
    create_directory "$BACKEND_DIR/src/apps" "root" "root" "755"
    create_directory "$BACKEND_DIR/src/apps/dto" "root" "root" "755"
    create_directory "$BACKEND_DIR/src/monitoring" "root" "root" "755"
    create_directory "$BACKEND_DIR/src/monitoring/dto" "root" "root" "755"
    create_directory "$BACKEND_DIR/src/dns" "root" "root" "755"
    create_directory "$BACKEND_DIR/src/dns/dto" "root" "root" "755"
    create_directory "$BACKEND_DIR/src/files" "root" "root" "755"
    create_directory "$BACKEND_DIR/src/files/dto" "root" "root" "755"
    create_directory "$BACKEND_DIR/src/common" "root" "root" "755"
    create_directory "$BACKEND_DIR/src/common/decorators" "root" "root" "755"
    create_directory "$BACKEND_DIR/src/common/filters" "root" "root" "755"
    create_directory "$BACKEND_DIR/src/common/guards" "root" "root" "755"
    create_directory "$BACKEND_DIR/src/common/interceptors" "root" "root" "755"
    create_directory "$BACKEND_DIR/src/database" "root" "root" "755"
    create_directory "$BACKEND_DIR/src/database/entities" "root" "root" "755"
    create_directory "$BACKEND_DIR/src/database/migrations" "root" "root" "755"
    
    log "SUCCESS" "Backend directory structure created"
}

# Create package.json and configuration files
create_package_files() {
    log "INFO" "Creating package.json and configuration files"
    
    cat > "$BACKEND_DIR/package.json" << 'EOF'
{
  "name": "server-panel-backend",
  "version": "1.0.0",
  "description": "cPanel-like Server Management Panel Backend",
  "author": "Server Panel",
  "private": true,
  "license": "MIT",
  "scripts": {
    "build": "nest build",
    "format": "prettier --write \"src/**/*.ts\" \"test/**/*.ts\"",
    "start": "nest start",
    "start:dev": "nest start --watch",
    "start:debug": "nest start --debug --watch",
    "start:prod": "node dist/main",
    "lint": "eslint \"{src,apps,libs,test}/**/*.ts\" --fix",
    "test": "jest",
    "test:watch": "jest --watch",
    "test:cov": "jest --coverage",
    "test:debug": "node --inspect-brk -r tsconfig-paths/register -r ts-node/register node_modules/.bin/jest --runInBand",
    "test:e2e": "jest --config ./test/jest-e2e.json"
  },
  "dependencies": {
    "@nestjs/common": "^10.0.0",
    "@nestjs/core": "^10.0.0",
    "@nestjs/platform-express": "^10.0.0",
    "@nestjs/typeorm": "^10.0.0",
    "@nestjs/jwt": "^10.1.0",
    "@nestjs/passport": "^10.0.0",
    "@nestjs/config": "^3.0.0",
    "@nestjs/schedule": "^3.0.1",
    "@nestjs/websockets": "^10.0.0",
    "@nestjs/platform-socket.io": "^10.0.0",
    "typeorm": "^0.3.17",
    "mysql2": "^3.6.0",
    "bcryptjs": "^2.4.3",
    "passport": "^0.6.0",
    "passport-jwt": "^4.0.1",
    "passport-local": "^1.0.0",
    "class-validator": "^0.14.0",
    "class-transformer": "^0.5.1",
    "dockerode": "^3.3.5",
    "node-cron": "^3.0.2",
    "axios": "^1.4.0",
    "multer": "^1.4.5-lts.1",
    "socket.io": "^4.7.2",
    "systeminformation": "^5.18.7",
    "reflect-metadata": "^0.1.13",
    "rxjs": "^7.8.1"
  },
  "devDependencies": {
    "@nestjs/cli": "^10.0.0",
    "@nestjs/schematics": "^10.0.0",
    "@nestjs/testing": "^10.0.0",
    "@types/bcryptjs": "^2.4.2",
    "@types/express": "^4.17.17",
    "@types/jest": "^29.5.2",
    "@types/multer": "^1.4.7",
    "@types/node": "^20.3.1",
    "@types/node-cron": "^3.0.7",
    "@types/passport-jwt": "^3.0.9",
    "@types/passport-local": "^1.0.35",
    "@types/supertest": "^2.0.12",
    "eslint": "^8.42.0",
    "jest": "^29.5.0",
    "prettier": "^2.8.8",
    "source-map-support": "^0.5.21",
    "supertest": "^6.3.3",
    "ts-jest": "^29.1.0",
    "ts-loader": "^9.4.3",
    "ts-node": "^10.9.1",
    "tsconfig-paths": "^4.2.0",
    "typescript": "^5.1.3"
  }
}
EOF

    # Create TypeScript configuration
    cat > "$BACKEND_DIR/tsconfig.json" << 'EOF'
{
  "compilerOptions": {
    "module": "commonjs",
    "declaration": true,
    "removeComments": true,
    "emitDecoratorMetadata": true,
    "experimentalDecorators": true,
    "allowSyntheticDefaultImports": true,
    "target": "ES2021",
    "sourceMap": true,
    "outDir": "./dist",
    "baseUrl": "./",
    "incremental": true,
    "skipLibCheck": true,
    "strictNullChecks": false,
    "noImplicitAny": false,
    "strictBindCallApply": false,
    "forceConsistentCasingInFileNames": false,
    "noFallthroughCasesInSwitch": false,
    "paths": {
      "@/*": ["src/*"]
    }
  }
}
EOF

    # Create NestJS CLI configuration
    cat > "$BACKEND_DIR/nest-cli.json" << 'EOF'
{
  "$schema": "https://json.schemastore.org/nest-cli",
  "collection": "@nestjs/schematics",
  "sourceRoot": "src",
  "compilerOptions": {
    "deleteOutDir": true
  }
}
EOF

    log "SUCCESS" "Package files created"
}

# Create main application files
create_backend_core() {
    log "INFO" "Creating backend core files"
    
    # Main application file
    cat > "$BACKEND_DIR/src/main.ts" << 'EOF'
import { NestFactory } from '@nestjs/core';
import { ValidationPipe } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { AppModule } from './app.module';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  const configService = app.get(ConfigService);
  
  // Enable CORS
  app.enableCors({
    origin: [
      'http://localhost:3000',
      'https://localhost:3000',
      configService.get('FRONTEND_URL', 'http://localhost:3000')
    ],
    credentials: true,
  });
  
  // Global validation pipe
  app.useGlobalPipes(new ValidationPipe({
    transform: true,
    whitelist: true,
    forbidNonWhitelisted: true,
  }));
  
  // API prefix
  app.setGlobalPrefix('api');
  
  // Swagger documentation
  const config = new DocumentBuilder()
    .setTitle('Server Panel API')
    .setDescription('cPanel-like Server Management Panel API')
    .setVersion('1.0')
    .addBearerAuth()
    .build();
  const document = SwaggerModule.createDocument(app, config);
  SwaggerModule.setup('api/docs', app, document);
  
  const port = configService.get('PORT', 3001);
  await app.listen(port);
  console.log(`Server Panel Backend running on port ${port}`);
}
bootstrap();
EOF

    # App module
    cat > "$BACKEND_DIR/src/app.module.ts" << 'EOF'
import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ScheduleModule } from '@nestjs/schedule';
import { AuthModule } from './auth/auth.module';
import { UsersModule } from './users/users.module';
import { AppsModule } from './apps/apps.module';
import { MonitoringModule } from './monitoring/monitoring.module';
import { DnsModule } from './dns/dns.module';
import { FilesModule } from './files/files.module';
import { AppController } from './app.controller';
import { AppService } from './app.service';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      envFilePath: ['.env.local', '.env'],
    }),
    TypeOrmModule.forRootAsync({
      imports: [ConfigModule],
      useFactory: (configService: ConfigService) => ({
        type: 'mysql',
        host: configService.get('DB_HOST', 'localhost'),
        port: configService.get('DB_PORT', 3306),
        username: configService.get('DB_USERNAME', 'panel_admin'),
        password: configService.get('DB_PASSWORD'),
        database: configService.get('DB_NAME', 'server_panel'),
        autoLoadEntities: true,
        synchronize: configService.get('NODE_ENV') !== 'production',
        logging: configService.get('NODE_ENV') !== 'production',
      }),
      inject: [ConfigService],
    }),
    ScheduleModule.forRoot(),
    AuthModule,
    UsersModule,
    AppsModule,
    MonitoringModule,
    DnsModule,
    FilesModule,
  ],
  controllers: [AppController],
  providers: [AppService],
})
export class AppModule {}
EOF

    # App controller
    cat > "$BACKEND_DIR/src/app.controller.ts" << 'EOF'
import { Controller, Get } from '@nestjs/common';
import { AppService } from './app.service';

@Controller()
export class AppController {
  constructor(private readonly appService: AppService) {}

  @Get()
  getHello(): string {
    return this.appService.getHello();
  }

  @Get('health')
  getHealth() {
    return {
      status: 'ok',
      timestamp: new Date().toISOString(),
      service: 'Server Panel Backend'
    };
  }
}
EOF

    # App service
    cat > "$BACKEND_DIR/src/app.service.ts" << 'EOF'
import { Injectable } from '@nestjs/common';

@Injectable()
export class AppService {
  getHello(): string {
    return 'Server Panel Backend API is running!';
  }
}
EOF

    log "SUCCESS" "Backend core files created"
}

# Create authentication system
create_auth_system() {
    log "INFO" "Creating authentication system"
    
    # User entity
    cat > "$BACKEND_DIR/src/users/user.entity.ts" << 'EOF'
import { Entity, Column, PrimaryGeneratedColumn, CreateDateColumn, UpdateDateColumn, OneToMany } from 'typeorm';
import { Exclude } from 'class-transformer';

export enum UserRole {
  ADMIN = 'admin',
  USER = 'user',
}

export enum UserStatus {
  ACTIVE = 'active',
  SUSPENDED = 'suspended',
  PENDING = 'pending',
}

@Entity('users')
export class User {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ unique: true })
  email: string;

  @Column()
  name: string;

  @Column()
  @Exclude()
  password: string;

  @Column({
    type: 'enum',
    enum: UserRole,
    default: UserRole.USER,
  })
  role: UserRole;

  @Column({
    type: 'enum',
    enum: UserStatus,
    default: UserStatus.ACTIVE,
  })
  status: UserStatus;

  @Column({ type: 'json', nullable: true })
  limits: {
    maxApps?: number;
    maxDatabases?: number;
    maxDiskSpace?: number; // in MB
    maxBandwidth?: number; // in MB
  };

  @Column({ type: 'json', nullable: true })
  settings: {
    timezone?: string;
    language?: string;
    notifications?: boolean;
  };

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;

  @Column({ nullable: true })
  lastLoginAt: Date;

  @Column({ nullable: true })
  resetToken: string;

  @Column({ nullable: true })
  resetTokenExpiry: Date;
}
EOF

    # Auth module
    cat > "$BACKEND_DIR/src/auth/auth.module.ts" << 'EOF'
import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { PassportModule } from '@nestjs/passport';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AuthService } from './auth.service';
import { AuthController } from './auth.controller';
import { JwtStrategy } from './jwt.strategy';
import { LocalStrategy } from './local.strategy';
import { User } from '../users/user.entity';
import { UsersModule } from '../users/users.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([User]),
    PassportModule,
    JwtModule.registerAsync({
      imports: [ConfigModule],
      useFactory: async (configService: ConfigService) => ({
        secret: configService.get('JWT_SECRET', 'server-panel-jwt-secret-key'),
        signOptions: { expiresIn: '7d' },
      }),
      inject: [ConfigService],
    }),
    UsersModule,
  ],
  providers: [AuthService, LocalStrategy, JwtStrategy],
  controllers: [AuthController],
  exports: [AuthService],
})
export class AuthModule {}
EOF

    # Auth service
    cat > "$BACKEND_DIR/src/auth/auth.service.ts" << 'EOF'
import { Injectable, UnauthorizedException, ConflictException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import * as bcrypt from 'bcryptjs';
import { User, UserRole, UserStatus } from '../users/user.entity';
import { CreateUserDto } from './dto/create-user.dto';
import { LoginDto } from './dto/login.dto';

@Injectable()
export class AuthService {
  constructor(
    @InjectRepository(User)
    private readonly userRepository: Repository<User>,
    private readonly jwtService: JwtService,
  ) {}

  async validateUser(email: string, password: string): Promise<any> {
    const user = await this.userRepository.findOne({ 
      where: { email, status: UserStatus.ACTIVE } 
    });
    
    if (user && await bcrypt.compare(password, user.password)) {
      const { password: _, ...result } = user;
      return result;
    }
    return null;
  }

  async login(loginDto: LoginDto) {
    const user = await this.validateUser(loginDto.email, loginDto.password);
    if (!user) {
      throw new UnauthorizedException('Invalid credentials');
    }

    // Update last login
    await this.userRepository.update(user.id, { lastLoginAt: new Date() });

    const payload = { 
      email: user.email, 
      sub: user.id, 
      role: user.role 
    };

    return {
      access_token: this.jwtService.sign(payload),
      user: {
        id: user.id,
        email: user.email,
        name: user.name,
        role: user.role,
        status: user.status,
      },
    };
  }

  async register(createUserDto: CreateUserDto) {
    const existingUser = await this.userRepository.findOne({
      where: { email: createUserDto.email },
    });

    if (existingUser) {
      throw new ConflictException('User with this email already exists');
    }

    const hashedPassword = await bcrypt.hash(createUserDto.password, 12);
    
    const user = this.userRepository.create({
      ...createUserDto,
      password: hashedPassword,
      role: UserRole.USER,
      status: UserStatus.ACTIVE,
      limits: {
        maxApps: 10,
        maxDatabases: 10,
        maxDiskSpace: 1000, // 1GB
        maxBandwidth: 10000, // 10GB
      },
    });

    const savedUser = await this.userRepository.save(user);
    const { password: _, ...result } = savedUser;
    return result;
  }

  async findById(id: string): Promise<User> {
    return this.userRepository.findOne({ where: { id } });
  }

  async createAdminUser(email: string, password: string, name: string) {
    const hashedPassword = await bcrypt.hash(password, 12);
    
    const admin = this.userRepository.create({
      email,
      password: hashedPassword,
      name,
      role: UserRole.ADMIN,
      status: UserStatus.ACTIVE,
    });

    return this.userRepository.save(admin);
  }
}
EOF

    # Auth controller
    cat > "$BACKEND_DIR/src/auth/auth.controller.ts" << 'EOF'
import { Controller, Post, Body, Get, UseGuards, Request } from '@nestjs/common';
import { AuthService } from './auth.service';
import { JwtAuthGuard } from './jwt-auth.guard';
import { CreateUserDto } from './dto/create-user.dto';
import { LoginDto } from './dto/login.dto';

@Controller('auth')
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  @Post('register')
  async register(@Body() createUserDto: CreateUserDto) {
    return this.authService.register(createUserDto);
  }

  @Post('login')
  async login(@Body() loginDto: LoginDto) {
    return this.authService.login(loginDto);
  }

  @UseGuards(JwtAuthGuard)
  @Get('me')
  async getProfile(@Request() req) {
    const user = await this.authService.findById(req.user.userId);
    const { password: _, ...result } = user;
    return { user: result };
  }
}
EOF

    # JWT Strategy
    cat > "$BACKEND_DIR/src/auth/jwt.strategy.ts" << 'EOF'
import { ExtractJwt, Strategy } from 'passport-jwt';
import { PassportStrategy } from '@nestjs/passport';
import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy) {
  constructor(private configService: ConfigService) {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      ignoreExpiration: false,
      secretOrKey: configService.get('JWT_SECRET', 'server-panel-jwt-secret-key'),
    });
  }

  async validate(payload: any) {
    return { 
      userId: payload.sub, 
      email: payload.email, 
      role: payload.role 
    };
  }
}
EOF

    # Local Strategy
    cat > "$BACKEND_DIR/src/auth/local.strategy.ts" << 'EOF'
import { Strategy } from 'passport-local';
import { PassportStrategy } from '@nestjs/passport';
import { Injectable, UnauthorizedException } from '@nestjs/common';
import { AuthService } from './auth.service';

@Injectable()
export class LocalStrategy extends PassportStrategy(Strategy) {
  constructor(private authService: AuthService) {
    super({ usernameField: 'email' });
  }

  async validate(email: string, password: string): Promise<any> {
    const user = await this.authService.validateUser(email, password);
    if (!user) {
      throw new UnauthorizedException();
    }
    return user;
  }
}
EOF

    # JWT Auth Guard
    cat > "$BACKEND_DIR/src/auth/jwt-auth.guard.ts" << 'EOF'
import { Injectable } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';

@Injectable()
export class JwtAuthGuard extends AuthGuard('jwt') {}
EOF

    # Admin Guard
    cat > "$BACKEND_DIR/src/auth/admin.guard.ts" << 'EOF'
import { Injectable, CanActivate, ExecutionContext } from '@nestjs/common';
import { UserRole } from '../users/user.entity';

@Injectable()
export class AdminGuard implements CanActivate {
  canActivate(context: ExecutionContext): boolean {
    const request = context.switchToHttp().getRequest();
    const user = request.user;
    return user && user.role === UserRole.ADMIN;
  }
}
EOF

    # DTOs
    cat > "$BACKEND_DIR/src/auth/dto/create-user.dto.ts" << 'EOF'
import { IsEmail, IsString, MinLength, MaxLength } from 'class-validator';

export class CreateUserDto {
  @IsEmail()
  email: string;

  @IsString()
  @MinLength(2)
  @MaxLength(50)
  name: string;

  @IsString()
  @MinLength(8)
  @MaxLength(100)
  password: string;
}
EOF

    cat > "$BACKEND_DIR/src/auth/dto/login.dto.ts" << 'EOF'
import { IsEmail, IsString } from 'class-validator';

export class LoginDto {
  @IsEmail()
  email: string;

  @IsString()
  password: string;
}
EOF

    log "SUCCESS" "Authentication system created"
}

# Create user management system
create_user_management() {
    log "INFO" "Creating user management system"
    
    # Users module
    cat > "$BACKEND_DIR/src/users/users.module.ts" << 'EOF'
import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { UsersService } from './users.service';
import { UsersController } from './users.controller';
import { User } from './user.entity';

@Module({
  imports: [TypeOrmModule.forFeature([User])],
  providers: [UsersService],
  controllers: [UsersController],
  exports: [UsersService],
})
export class UsersModule {}
EOF

    # Users service
    cat > "$BACKEND_DIR/src/users/users.service.ts" << 'EOF'
import { Injectable, NotFoundException, ForbiddenException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, FindManyOptions } from 'typeorm';
import * as bcrypt from 'bcryptjs';
import { User, UserStatus, UserRole } from './user.entity';
import { UpdateUserDto } from './dto/update-user.dto';
import { CreateUserDto } from '../auth/dto/create-user.dto';

@Injectable()
export class UsersService {
  constructor(
    @InjectRepository(User)
    private readonly userRepository: Repository<User>,
  ) {}

  async findAll(page: number = 1, limit: number = 10, search?: string) {
    const skip = (page - 1) * limit;
    
    const queryBuilder = this.userRepository.createQueryBuilder('user');
    
    if (search) {
      queryBuilder.where(
        'user.email LIKE :search OR user.name LIKE :search',
        { search: `%${search}%` }
      );
    }
    
    const [users, total] = await queryBuilder
      .select([
        'user.id',
        'user.email', 
        'user.name',
        'user.role',
        'user.status',
        'user.limits',
        'user.createdAt',
        'user.lastLoginAt'
      ])
      .skip(skip)
      .take(limit)
      .orderBy('user.createdAt', 'DESC')
      .getManyAndCount();

    return {
      users,
      pagination: {
        page,
        limit,
        total,
        pages: Math.ceil(total / limit),
      },
    };
  }

  async findOne(id: string): Promise<User> {
    const user = await this.userRepository.findOne({ where: { id } });
    if (!user) {
      throw new NotFoundException('User not found');
    }
    return user;
  }

  async create(createUserDto: CreateUserDto): Promise<User> {
    const hashedPassword = await bcrypt.hash(createUserDto.password, 12);
    
    const user = this.userRepository.create({
      ...createUserDto,
      password: hashedPassword,
      role: UserRole.USER,
      status: UserStatus.ACTIVE,
      limits: {
        maxApps: 10,
        maxDatabases: 10,
        maxDiskSpace: 1000,
        maxBandwidth: 10000,
      },
    });

    const savedUser = await this.userRepository.save(user);
    delete savedUser.password;
    return savedUser;
  }

  async update(id: string, updateUserDto: UpdateUserDto): Promise<User> {
    const user = await this.findOne(id);
    
    if (updateUserDto.password) {
      updateUserDto.password = await bcrypt.hash(updateUserDto.password, 12);
    }

    await this.userRepository.update(id, updateUserDto);
    const updatedUser = await this.findOne(id);
    delete updatedUser.password;
    return updatedUser;
  }

  async remove(id: string): Promise<void> {
    const user = await this.findOne(id);
    
    if (user.role === UserRole.ADMIN) {
      throw new ForbiddenException('Cannot delete admin user');
    }
    
    await this.userRepository.delete(id);
  }

  async suspend(id: string): Promise<User> {
    const user = await this.findOne(id);
    
    if (user.role === UserRole.ADMIN) {
      throw new ForbiddenException('Cannot suspend admin user');
    }
    
    await this.userRepository.update(id, { status: UserStatus.SUSPENDED });
    return this.findOne(id);
  }

  async activate(id: string): Promise<User> {
    await this.userRepository.update(id, { status: UserStatus.ACTIVE });
    return this.findOne(id);
  }

  async updateLimits(id: string, limits: any): Promise<User> {
    await this.userRepository.update(id, { limits });
    return this.findOne(id);
  }

  async getStats() {
    const totalUsers = await this.userRepository.count();
    const activeUsers = await this.userRepository.count({ 
      where: { status: UserStatus.ACTIVE } 
    });
    const suspendedUsers = await this.userRepository.count({ 
      where: { status: UserStatus.SUSPENDED } 
    });
    const adminUsers = await this.userRepository.count({ 
      where: { role: UserRole.ADMIN } 
    });

    return {
      total: totalUsers,
      active: activeUsers,
      suspended: suspendedUsers,
      admins: adminUsers,
    };
  }
}
EOF

    # Users controller
    cat > "$BACKEND_DIR/src/users/users.controller.ts" << 'EOF'
import { 
  Controller, 
  Get, 
  Post, 
  Body, 
  Patch, 
  Param, 
  Delete, 
  UseGuards,
  Query,
  Request
} from '@nestjs/common';
import { UsersService } from './users.service';
import { UpdateUserDto } from './dto/update-user.dto';
import { CreateUserDto } from '../auth/dto/create-user.dto';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { AdminGuard } from '../auth/admin.guard';

@Controller('users')
@UseGuards(JwtAuthGuard)
export class UsersController {
  constructor(private readonly usersService: UsersService) {}

  @Get()
  @UseGuards(AdminGuard)
  findAll(
    @Query('page') page: number = 1,
    @Query('limit') limit: number = 10,
    @Query('search') search?: string,
  ) {
    return this.usersService.findAll(page, limit, search);
  }

  @Get('stats')
  @UseGuards(AdminGuard)
  getStats() {
    return this.usersService.getStats();
  }

  @Get('profile')
  async getProfile(@Request() req) {
    return this.usersService.findOne(req.user.userId);
  }

  @Patch('profile')
  async updateProfile(@Request() req, @Body() updateUserDto: UpdateUserDto) {
    return this.usersService.update(req.user.userId, updateUserDto);
  }

  @Get(':id')
  @UseGuards(AdminGuard)
  findOne(@Param('id') id: string) {
    return this.usersService.findOne(id);
  }

  @Post()
  @UseGuards(AdminGuard)
  create(@Body() createUserDto: CreateUserDto) {
    return this.usersService.create(createUserDto);
  }

  @Patch(':id')
  @UseGuards(AdminGuard)
  update(@Param('id') id: string, @Body() updateUserDto: UpdateUserDto) {
    return this.usersService.update(id, updateUserDto);
  }

  @Delete(':id')
  @UseGuards(AdminGuard)
  remove(@Param('id') id: string) {
    return this.usersService.remove(id);
  }

  @Patch(':id/suspend')
  @UseGuards(AdminGuard)
  suspend(@Param('id') id: string) {
    return this.usersService.suspend(id);
  }

  @Patch(':id/activate')
  @UseGuards(AdminGuard)
  activate(@Param('id') id: string) {
    return this.usersService.activate(id);
  }

  @Patch(':id/limits')
  @UseGuards(AdminGuard)
  updateLimits(@Param('id') id: string, @Body() limits: any) {
    return this.usersService.updateLimits(id, limits);
  }
}
EOF

    # Update user DTO
    cat > "$BACKEND_DIR/src/users/dto/update-user.dto.ts" << 'EOF'
import { IsEmail, IsString, MinLength, MaxLength, IsOptional, IsEnum } from 'class-validator';
import { UserRole, UserStatus } from '../user.entity';

export class UpdateUserDto {
  @IsOptional()
  @IsEmail()
  email?: string;

  @IsOptional()
  @IsString()
  @MinLength(2)
  @MaxLength(50)
  name?: string;

  @IsOptional()
  @IsString()
  @MinLength(8)
  @MaxLength(100)
  password?: string;

  @IsOptional()
  @IsEnum(UserRole)
  role?: UserRole;

  @IsOptional()
  @IsEnum(UserStatus)
  status?: UserStatus;

  @IsOptional()
  limits?: {
    maxApps?: number;
    maxDatabases?: number;
    maxDiskSpace?: number;
    maxBandwidth?: number;
  };

  @IsOptional()
  settings?: {
    timezone?: string;
    language?: string;
    notifications?: boolean;
  };
}
EOF

    log "SUCCESS" "User management system created"
}

# Create application management system
create_app_management() {
    log "INFO" "Creating application management system"
    
    # App entity
    cat > "$BACKEND_DIR/src/apps/app.entity.ts" << 'EOF'
import { Entity, Column, PrimaryGeneratedColumn, CreateDateColumn, UpdateDateColumn, ManyToOne, JoinColumn } from 'typeorm';
import { User } from '../users/user.entity';

export enum AppType {
  WORDPRESS = 'wordpress',
  PHP = 'php',
  NODEJS = 'nodejs',
  PYTHON = 'python',
  STATIC = 'static',
  CUSTOM = 'custom',
}

export enum AppStatus {
  RUNNING = 'running',
  STOPPED = 'stopped',
  BUILDING = 'building',
  ERROR = 'error',
  STARTING = 'starting',
  STOPPING = 'stopping',
}

@Entity('apps')
export class App {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column()
  name: string;

  @Column()
  domain: string;

  @Column({
    type: 'enum',
    enum: AppType,
  })
  type: AppType;

  @Column({
    type: 'enum',
    enum: AppStatus,
    default: AppStatus.STOPPED,
  })
  status: AppStatus;

  @Column({ nullable: true })
  containerId: string;

  @Column()
  userId: string;

  @ManyToOne(() => User)
  @JoinColumn({ name: 'userId' })
  user: User;

  @Column({ type: 'json', nullable: true })
  config: {
    phpVersion?: string;
    nodeVersion?: string;
    pythonVersion?: string;
    database?: {
      type: string;
      name: string;
      user: string;
      password: string;
    };
    ssl?: boolean;
    subdomain?: string;
    environment?: Record<string, string>;
    buildCommand?: string;
    startCommand?: string;
    gitRepo?: string;
    gitBranch?: string;
  };

  @Column({ type: 'json', nullable: true })
  resources: {
    cpu?: number;
    memory?: number;
    disk?: number;
  };

  @Column({ type: 'int', default: 80 })
  port: number;

  @Column({ type: 'text', nullable: true })
  description: string;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;

  @Column({ nullable: true })
  lastDeployedAt: Date;
}
EOF

    # Apps module
    cat > "$BACKEND_DIR/src/apps/apps.module.ts" << 'EOF'
import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AppsService } from './apps.service';
import { AppsController } from './apps.controller';
import { DockerService } from './docker.service';
import { App } from './app.entity';
import { User } from '../users/user.entity';

@Module({
  imports: [TypeOrmModule.forFeature([App, User])],
  providers: [AppsService, DockerService],
  controllers: [AppsController],
  exports: [AppsService, DockerService],
})
export class AppsModule {}
EOF

    # Docker service for container management
    cat > "$BACKEND_DIR/src/apps/docker.service.ts" << 'EOF'
import { Injectable, Logger } from '@nestjs/common';
import * as Docker from 'dockerode';
import * as fs from 'fs';
import * as path from 'path';
import { AppType } from './app.entity';

@Injectable()
export class DockerService {
  private readonly logger = new Logger(DockerService.name);
  private docker: Docker;

  constructor() {
    this.docker = new Docker();
  }

  async createWordPressApp(appName: string, domain: string, dbConfig: any, userId: string) {
    const imageName = `${appName}-wordpress`;
    const containerName = `panel-${appName}`;
    const dataPath = `/var/server-panel/users/${userId}/${appName}`;

    // Create directories
    await this.ensureDirectory(dataPath);
    await this.ensureDirectory(`${dataPath}/wordpress`);

    // Create docker-compose.yml
    const composeContent = `
version: '3.8'
services:
  wordpress:
    image: wordpress:latest
    container_name: ${containerName}
    restart: unless-stopped
    networks:
      - server-panel
    environment:
      WORDPRESS_DB_HOST: mysql:3306
      WORDPRESS_DB_USER: ${dbConfig.user}
      WORDPRESS_DB_PASSWORD: ${dbConfig.password}
      WORDPRESS_DB_NAME: ${dbConfig.name}
    volumes:
      - ${dataPath}/wordpress:/var/www/html
    labels:
      - "panel.app=${appName}"
      - "panel.domain=${domain}"
      - "panel.user=${userId}"
      - "panel.type=wordpress"

networks:
  server-panel:
    external: true
`;

    fs.writeFileSync(`${dataPath}/docker-compose.yml`, composeContent);
    
    // Start container
    const container = await this.runCommand(`cd ${dataPath} && docker-compose up -d`);
    
    return containerName;
  }

  async createPHPApp(appName: string, domain: string, phpVersion: string, userId: string) {
    const containerName = `panel-${appName}`;
    const dataPath = `/var/server-panel/users/${userId}/${appName}`;

    await this.ensureDirectory(dataPath);
    await this.ensureDirectory(`${dataPath}/public`);

    // Create PHP Dockerfile
    const dockerfile = `
FROM php:${phpVersion}-fpm-alpine

# Install PHP extensions
RUN docker-php-ext-install pdo pdo_mysql mysqli

# Install Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Set working directory
WORKDIR /var/www/html

# Copy application
COPY . .

# Install dependencies if composer.json exists
RUN if [ -f composer.json ]; then composer install --no-dev --optimize-autoloader; fi

EXPOSE 80
`;

    const nginxConfig = `
server {
    listen 80;
    server_name ${domain};
    root /var/www/html/public;
    index index.php index.html;

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location ~ \\.php$ {
        fastcgi_pass php:9000;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
    }
}
`;

    const composeContent = `
version: '3.8'
services:
  php:
    build: .
    container_name: ${containerName}
    restart: unless-stopped
    networks:
      - server-panel
    volumes:
      - ${dataPath}:/var/www/html
    labels:
      - "panel.app=${appName}"
      - "panel.domain=${domain}"
      - "panel.user=${userId}"
      - "panel.type=php"

  nginx:
    image: nginx:alpine
    container_name: ${containerName}-nginx
    restart: unless-stopped
    networks:
      - server-panel
    volumes:
      - ${dataPath}:/var/www/html
      - ${dataPath}/nginx.conf:/etc/nginx/conf.d/default.conf
    depends_on:
      - php
    labels:
      - "panel.app=${appName}"
      - "panel.domain=${domain}"

networks:
  server-panel:
    external: true
`;

    fs.writeFileSync(`${dataPath}/Dockerfile`, dockerfile);
    fs.writeFileSync(`${dataPath}/nginx.conf`, nginxConfig);
    fs.writeFileSync(`${dataPath}/docker-compose.yml`, composeContent);

    // Create sample index.php if it doesn't exist
    if (!fs.existsSync(`${dataPath}/public/index.php`)) {
      fs.writeFileSync(`${dataPath}/public/index.php`, `<?php
echo "<h1>Welcome to your PHP Application!</h1>";
echo "<p>PHP Version: " . PHP_VERSION . "</p>";
echo "<p>Server Time: " . date('Y-m-d H:i:s') . "</p>";
phpinfo();
?>`);
    }

    await this.runCommand(`cd ${dataPath} && docker-compose up -d --build`);
    return containerName;
  }

  async createNodeJSApp(appName: string, domain: string, nodeVersion: string, userId: string) {
    const containerName = `panel-${appName}`;
    const dataPath = `/var/server-panel/users/${userId}/${appName}`;

    await this.ensureDirectory(dataPath);

    const dockerfile = `
FROM node:${nodeVersion}-alpine

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci --only=production

# Copy app source
COPY . .

# Create non-root user
RUN addgroup -g 1001 -S nodejs
RUN adduser -S nextjs -u 1001

USER nextjs

EXPOSE 3000

CMD ["npm", "start"]
`;

    const composeContent = `
version: '3.8'
services:
  app:
    build: .
    container_name: ${containerName}
    restart: unless-stopped
    networks:
      - server-panel
    volumes:
      - ${dataPath}:/app
    environment:
      - NODE_ENV=production
      - PORT=3000
    labels:
      - "panel.app=${appName}"
      - "panel.domain=${domain}"
      - "panel.user=${userId}"
      - "panel.type=nodejs"

networks:
  server-panel:
    external: true
`;

    fs.writeFileSync(`${dataPath}/Dockerfile`, dockerfile);
    fs.writeFileSync(`${dataPath}/docker-compose.yml`, composeContent);

    // Create sample package.json and app.js if they don't exist
    if (!fs.existsSync(`${dataPath}/package.json`)) {
      const packageJson = {
        name: appName,
        version: '1.0.0',
        description: 'Server Panel Node.js Application',
        main: 'app.js',
        scripts: {
          start: 'node app.js'
        },
        dependencies: {
          express: '^4.18.0'
        }
      };
      fs.writeFileSync(`${dataPath}/package.json`, JSON.stringify(packageJson, null, 2));
    }

    if (!fs.existsSync(`${dataPath}/app.js`)) {
      const appJs = `
const express = require('express');
const app = express();
const port = process.env.PORT || 3000;

app.get('/', (req, res) => {
  res.send(\`
    <h1>Welcome to your Node.js Application!</h1>
    <p>Node Version: \${process.version}</p>
    <p>Server Time: \${new Date().toISOString()}</p>
    <p>App: ${appName}</p>
  \`);
});

app.listen(port, () => {
  console.log(\`Server running on port \${port}\`);
});
`;
      fs.writeFileSync(`${dataPath}/app.js`, appJs);
    }

    await this.runCommand(`cd ${dataPath} && docker-compose up -d --build`);
    return containerName;
  }

  async createPythonApp(appName: string, domain: string, pythonVersion: string, userId: string) {
    const containerName = `panel-${appName}`;
    const dataPath = `/var/server-panel/users/${userId}/${appName}`;

    await this.ensureDirectory(dataPath);

    const dockerfile = `
FROM python:${pythonVersion}-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \\
    gcc \\
    && rm -rf /var/lib/apt/lists/*

# Copy requirements first for better caching
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy application
COPY . .

# Create non-root user
RUN useradd --create-home --shell /bin/bash app
USER app

EXPOSE 8000

CMD ["python", "app.py"]
`;

    const composeContent = `
version: '3.8'
services:
  app:
    build: .
    container_name: ${containerName}
    restart: unless-stopped
    networks:
      - server-panel
    volumes:
      - ${dataPath}:/app
    environment:
      - PYTHONPATH=/app
      - FLASK_ENV=production
    labels:
      - "panel.app=${appName}"
      - "panel.domain=${domain}"
      - "panel.user=${userId}"
      - "panel.type=python"

networks:
  server-panel:
    external: true
`;

    fs.writeFileSync(`${dataPath}/Dockerfile`, dockerfile);
    fs.writeFileSync(`${dataPath}/docker-compose.yml`, composeContent);

    // Create sample requirements.txt and app.py if they don't exist
    if (!fs.existsSync(`${dataPath}/requirements.txt`)) {
      fs.writeFileSync(`${dataPath}/requirements.txt`, 'Flask==2.3.0\\nGunicorn==20.1.0');
    }

    if (!fs.existsSync(`${dataPath}/app.py`)) {
      const appPy = `
from flask import Flask
import sys
from datetime import datetime

app = Flask(__name__)

@app.route('/')
def hello():
    return f'''
    <h1>Welcome to your Python Application!</h1>
    <p>Python Version: {sys.version}</p>
    <p>Server Time: {datetime.now().isoformat()}</p>
    <p>App: ${appName}</p>
    <p>Framework: Flask</p>
    '''

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8000, debug=False)
`;
      fs.writeFileSync(`${dataPath}/app.py`, appPy);
    }

    await this.runCommand(`cd ${dataPath} && docker-compose up -d --build`);
    return containerName;
  }

  async createStaticApp(appName: string, domain: string, userId: string) {
    const containerName = `panel-${appName}`;
    const dataPath = `/var/server-panel/users/${userId}/${appName}`;

    await this.ensureDirectory(dataPath);
    await this.ensureDirectory(`${dataPath}/html`);

    const nginxConfig = `
server {
    listen 80;
    server_name ${domain};
    root /usr/share/nginx/html;
    index index.html index.htm;

    location / {
        try_files $uri $uri/ /index.html;
    }

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
}
`;

    const composeContent = `
version: '3.8'
services:
  nginx:
    image: nginx:alpine
    container_name: ${containerName}
    restart: unless-stopped
    networks:
      - server-panel
    volumes:
      - ${dataPath}/html:/usr/share/nginx/html
      - ${dataPath}/nginx.conf:/etc/nginx/conf.d/default.conf
    labels:
      - "panel.app=${appName}"
      - "panel.domain=${domain}"
      - "panel.user=${userId}"
      - "panel.type=static"

networks:
  server-panel:
    external: true
`;

    fs.writeFileSync(`${dataPath}/nginx.conf`, nginxConfig);
    fs.writeFileSync(`${dataPath}/docker-compose.yml`, composeContent);

    // Create sample index.html if it doesn't exist
    if (!fs.existsSync(`${dataPath}/html/index.html`)) {
      const indexHtml = `
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>${appName}</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        .container { max-width: 800px; margin: 0 auto; }
        h1 { color: #333; }
        .info { background: #f4f4f4; padding: 20px; border-radius: 5px; }
    </style>
</head>
<body>
    <div class="container">
        <h1>Welcome to your Static Website!</h1>
        <div class="info">
            <p><strong>App Name:</strong> ${appName}</p>
            <p><strong>Domain:</strong> ${domain}</p>
            <p><strong>Type:</strong> Static HTML</p>
            <p><strong>Server Time:</strong> <span id="time"></span></p>
        </div>
        <p>Edit the files in the html/ directory to customize your website.</p>
    </div>
    <script>
        document.getElementById('time').textContent = new Date().toLocaleString();
    </script>
</body>
</html>
`;
      fs.writeFileSync(`${dataPath}/html/index.html`, indexHtml);
    }

    await this.runCommand(`cd ${dataPath} && docker-compose up -d`);
    return containerName;
  }

  async getContainerInfo(containerName: string) {
    try {
      const container = this.docker.getContainer(containerName);
      const info = await container.inspect();
      const stats = await container.stats({ stream: false });
      
      return {
        id: info.Id,
        name: info.Name,
        status: info.State.Status,
        running: info.State.Running,
        startedAt: info.State.StartedAt,
        image: info.Config.Image,
        ports: info.NetworkSettings.Ports,
        stats: {
          cpu: stats.cpu_stats,
          memory: stats.memory_stats,
          networks: stats.networks,
        }
      };
    } catch (error) {
      this.logger.error(`Error getting container info: ${error.message}`);
      return null;
    }
  }

  async startContainer(containerName: string) {
    try {
      const container = this.docker.getContainer(containerName);
      await container.start();
      return true;
    } catch (error) {
      this.logger.error(`Error starting container: ${error.message}`);
      return false;
    }
  }

  async stopContainer(containerName: string) {
    try {
      const container = this.docker.getContainer(containerName);
      await container.stop();
      return true;
    } catch (error) {
      this.logger.error(`Error stopping container: ${error.message}`);
      return false;
    }
  }

  async restartContainer(containerName: string) {
    try {
      const container = this.docker.getContainer(containerName);
      await container.restart();
      return true;
    } catch (error) {
      this.logger.error(`Error restarting container: ${error.message}`);
      return false;
    }
  }

  async removeContainer(containerName: string) {
    try {
      const container = this.docker.getContainer(containerName);
      await container.remove({ force: true });
      return true;
    } catch (error) {
      this.logger.error(`Error removing container: ${error.message}`);
      return false;
    }
  }

  async getContainerLogs(containerName: string, lines: number = 100) {
    try {
      const container = this.docker.getContainer(containerName);
      const logs = await container.logs({
        stdout: true,
        stderr: true,
        tail: lines,
        timestamps: true
      });
      return logs.toString();
    } catch (error) {
      this.logger.error(`Error getting container logs: ${error.message}`);
      return null;
    }
  }

  private async ensureDirectory(dirPath: string) {
    if (!fs.existsSync(dirPath)) {
      fs.mkdirSync(dirPath, { recursive: true });
    }
  }

  private async runCommand(command: string): Promise<string> {
    return new Promise((resolve, reject) => {
      const { exec } = require('child_process');
      exec(command, (error, stdout, stderr) => {
        if (error) {
          reject(error);
        } else {
          resolve(stdout);
        }
      });
    });
  }
}
EOF

    log "SUCCESS" "Application management system created"
}

# Complete the backend installation
complete_backend_setup() {
    log "INFO" "Completing backend setup"
    
    # Install dependencies
    cd "$BACKEND_DIR"
    npm install
    
    # Build the application
    npm run build
    
    # Create environment file
    cat > "$BACKEND_DIR/.env" << EOF
NODE_ENV=production
PORT=3001
DB_HOST=localhost
DB_PORT=3306
DB_NAME=server_panel
DB_USERNAME=$MYSQL_PANEL_USER
DB_PASSWORD=$MYSQL_PANEL_PASSWORD
JWT_SECRET=$(openssl rand -base64 32)
ADMIN_EMAIL=$EMAIL
FRONTEND_URL=https://$DOMAIN:3000
EOF

    # Set permissions
    chown -R root:root "$BACKEND_DIR"
    
    log "SUCCESS" "Backend setup completed"
}

# Create systemd service
create_backend_service() {
    log "INFO" "Creating backend service"
    
    cat > /etc/systemd/system/server-panel-backend.service << EOF
[Unit]
Description=Server Panel Backend API
After=network.target mysql.service
Wants=mysql.service

[Service]
Type=simple
User=root
WorkingDirectory=$BACKEND_DIR
Environment=NODE_ENV=production
ExecStart=/usr/bin/node dist/main.js
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable server-panel-backend
    
    log "SUCCESS" "Backend service created"
}

# Main installation function
main_install() {
    install_backend
    complete_backend_setup
    create_backend_service
    
    log "SUCCESS" "Server Panel Backend installation completed!"
    log "INFO" "Backend API will be available at: http://localhost:3001"
}

# Execute installation
main_install 