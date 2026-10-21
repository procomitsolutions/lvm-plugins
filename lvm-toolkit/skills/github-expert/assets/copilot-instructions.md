<!-- .github/copilot-instructions.md — instrucciones de repo para Copilot (chat, code review, cloud agent).
     Breves, concretas y verificables. Para reglas por ruta usa .github/instructions/*.instructions.md con `applyTo`. -->
# Proyecto
API REST en Node.js 24 + TypeScript. Código en `src/`, tests en `test/`, infraestructura en `infra/` (Terraform).

# Cómo compilar y probar
- Instalar: `npm ci`
- Lint: `npm run lint` (debe pasar sin warnings)
- Tests: `npm test`; agrega tests para todo cambio de comportamiento.
- Antes de proponer un PR, ejecuta lint y tests.

# Convenciones
- TypeScript estricto; nada de `any` sin justificación.
- Errores con la clase `AppError` de `src/errors.ts`.
- Commits estilo Conventional Commits.

# No hacer
- No modificar `infra/` ni `.github/workflows/` salvo pedido explícito.
- No agregar dependencias nuevas sin mencionarlo en la descripción del PR.
- Nunca escribir secretos ni credenciales en el código o los tests.
