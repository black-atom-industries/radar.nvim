import { createRouter } from "./router";
import { loadConfig } from "./lib/config";

export async function startApp() {
  const config = await loadConfig();
  const router = createRouter(config.routes);

  router.listen(config.port, () => {
    console.log(`listening on ${config.port}`);
  });
}
