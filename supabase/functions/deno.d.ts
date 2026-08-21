declare namespace Deno {
  export const env: {
    get(key: string): string | undefined;
    set(key: string, value: string): void;
  };
  export function serve(handler: (req: Request) => Promise<Response> | Response): void;
  export function serve(options: { port?: number; hostname?: string }, handler: (req: Request) => Promise<Response> | Response): void;
  export function exit(code?: number): never;
}

declare module 'jsr:*' {
  export const createClient: any;
  const content: any;
  export default content;
}

declare module 'jsr:@supabase/supabase-js@2.45.0' {
  export const createClient: any;
  const content: any;
  export default content;
}

declare module 'jsr:@supabase/supabase-js@2' {
  export const createClient: any;
  const content: any;
  export default content;
}

declare module 'npm:*' {
  export const GoogleAuth: any;
  const content: any;
  export default content;
}

declare module 'npm:google-auth-library@9' {
  export class GoogleAuth {
    constructor(options?: any);
    getClient(): Promise<any>;
    getAccessToken(): Promise<any>;
  }
}

declare module 'npm:google-auth-library' {
  export class GoogleAuth {
    constructor(options?: any);
    getClient(): Promise<any>;
    getAccessToken(): Promise<any>;
  }
}

declare module 'npm:bcryptjs@2.4.3' {
  const bcrypt: {
    hash(s: string, salt: number | string): Promise<string>;
    compare(s: string, hash: string): Promise<boolean>;
    hashSync(s: string, salt: number | string): string;
    compareSync(s: string, hash: string): boolean;
    genSalt(rounds?: number): Promise<string>;
  };
  export default bcrypt;
}

declare module 'npm:bcryptjs@2' {
  const bcrypt: {
    hash(s: string, salt: number | string): Promise<string>;
    compare(s: string, hash: string): Promise<boolean>;
    hashSync(s: string, salt: number | string): string;
    compareSync(s: string, hash: string): boolean;
    genSalt(rounds?: number): Promise<string>;
  };
  export default bcrypt;
}
