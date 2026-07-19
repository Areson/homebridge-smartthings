export class Command {
  component?: string;
  capability: string;
  command: string;
  arguments?: unknown[];

  constructor(capability: string, command: string, args?: unknown[], component?: string) {
    this.capability = capability;
    this.command = command;
    this.arguments = args;
    if (component) {
      this.component = component;
    }
  }
}