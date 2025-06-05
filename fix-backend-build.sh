#!/bin/bash

# Fix Backend Build Script
# Recreates problematic files with correct syntax

BACKEND_DIR="/opt/server-panel/backend"

echo "Fixing backend build errors..."

# Recreate apps.service.ts with correct TypeScript syntax
cat > "$BACKEND_DIR/src/apps/apps.service.ts" << 'EOF'
import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { App, AppType, AppStatus } from './app.entity';
import { DockerService } from './docker.service';

@Injectable()
export class AppsService {
  constructor(
    @InjectRepository(App)
    private appsRepository: Repository<App>,
    private dockerService: DockerService,
  ) {}

  async getAllApps(): Promise<App[]> {
    return this.appsRepository.find({ relations: ['user'] });
  }

  async getAppsByUser(userId: string): Promise<App[]> {
    return this.appsRepository.find({ 
      where: { userId },
      relations: ['user'] 
    });
  }

  async getAppById(id: string): Promise<App> {
    const app = await this.appsRepository.findOne({ 
      where: { id },
      relations: ['user'] 
    });
    
    if (!app) {
      throw new NotFoundException(`App with ID ${id} not found`);
    }
    
    return app;
  }

  async createApp(appData: {
    name: string;
    domain: string;
    type: AppType;
    userId: string;
    config?: any;
  }): Promise<App> {
    const app = this.appsRepository.create({
      ...appData,
      status: AppStatus.BUILDING,
    });

    const savedApp = await this.appsRepository.save(app);

    try {
      let containerId: string;
      
      switch (appData.type) {
        case AppType.WORDPRESS:
          containerId = await this.dockerService.createWordPressApp(
            appData.name,
            appData.domain,
            appData.config?.database || {},
            appData.userId
          );
          break;
        case AppType.PHP:
          containerId = await this.dockerService.createPHPApp(
            appData.name,
            appData.domain,
            appData.config?.phpVersion || '8.1',
            appData.userId
          );
          break;
        case AppType.NODEJS:
          containerId = await this.dockerService.createNodeJSApp(
            appData.name,
            appData.domain,
            appData.config?.nodeVersion || '18',
            appData.userId
          );
          break;
        case AppType.PYTHON:
          containerId = await this.dockerService.createPythonApp(
            appData.name,
            appData.domain,
            appData.config?.pythonVersion || '3.11',
            appData.userId
          );
          break;
        default:
          throw new Error(`Unsupported app type: ${appData.type}`);
      }

      savedApp.containerId = containerId;
      savedApp.status = AppStatus.RUNNING;
      savedApp.lastDeployedAt = new Date();
      
      return this.appsRepository.save(savedApp);
    } catch (error) {
      savedApp.status = AppStatus.ERROR;
      await this.appsRepository.save(savedApp);
      throw error;
    }
  }

  async updateApp(id: string, updateData: Partial<App>): Promise<App> {
    await this.appsRepository.update(id, updateData);
    return this.getAppById(id);
  }

  async deleteApp(id: string): Promise<void> {
    const app = await this.getAppById(id);
    
    if (app.containerId) {
      await this.dockerService.removeContainer(app.containerId);
    }
    
    await this.appsRepository.delete(id);
  }

  async startApp(id: string): Promise<void> {
    const app = await this.getAppById(id);
    
    if (app.containerId) {
      const started = await this.dockerService.startContainer(app.containerId);
      if (started) {
        app.status = AppStatus.RUNNING;
        await this.appsRepository.save(app);
      }
    }
  }

  async stopApp(id: string): Promise<void> {
    const app = await this.getAppById(id);
    
    if (app.containerId) {
      const stopped = await this.dockerService.stopContainer(app.containerId);
      if (stopped) {
        app.status = AppStatus.STOPPED;
        await this.appsRepository.save(app);
      }
    }
  }

  async restartApp(id: string): Promise<void> {
    const app = await this.getAppById(id);
    
    if (app.containerId) {
      const restarted = await this.dockerService.restartContainer(app.containerId);
      if (restarted) {
        app.status = AppStatus.RUNNING;
        await this.appsRepository.save(app);
      }
    }
  }

  async getAppLogs(id: string, lines: number = 100): Promise<string> {
    const app = await this.getAppById(id);
    
    if (app.containerId) {
      return this.dockerService.getContainerLogs(app.containerId, lines);
    }
    
    return 'No logs available';
  }
}
EOF

echo "Backend fixes applied. Try running the build again:"
echo "cd $BACKEND_DIR && npm run build" 