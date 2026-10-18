export function createRouter(routes: string[]) {
  return {
    listen(port: number, onReady: () => void) {
      onReady();
    },
    routes,
  };
}
