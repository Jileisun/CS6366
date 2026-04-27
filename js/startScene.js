import { mountSceneChrome, showFatalError } from "./sceneChrome.js";
import { getSceneConfig } from "./sceneRegistry.js";

const runners = {
  explorer: () => import("./explorerSceneRunner.js")
    .then(({ runExplorerScene }) => runExplorerScene),
  apollo: () => import("./apolloSceneRunner.js")
    .then(({ runApolloScene }) => runApolloScene),
  mandelbulb: () => import("./mandelbulbSceneRunner.js")
    .then(({ runMandelbulbScene }) => runMandelbulbScene),
};

export function bootScene(sceneKey) {
  try {
    const sceneConfig = getSceneConfig(sceneKey);
    const loadRunner = runners[sceneConfig.runtime];

    if (!loadRunner) {
      throw new Error(`No runner registered for runtime: ${sceneConfig.runtime}`);
    }

    mountSceneChrome(sceneConfig);
    loadRunner()
      .then((runner) => runner(sceneConfig))
      .catch(showFatalError);
  } catch (error) {
    showFatalError(error);
  }
}
