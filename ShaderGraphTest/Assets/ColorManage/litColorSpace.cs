using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.Rendering;

namespace SegaTechBlog
{
    public class litColorSpace : MonoBehaviour
    {
#if UNITY_EDITOR
        [MenuItem("SegaTechBlog/LightsIntensity/Linear")]
        private static void luliTrue()
        {
            GraphicsSettings.lightsUseLinearIntensity = true;
            EditorSceneManager.SaveCurrentModifiedScenesIfUserWantsTo();
            var scn = EditorSceneManager.GetSceneManagerSetup();
            EditorSceneManager.OpenScene(scn[0].path);
        }

        [MenuItem("SegaTechBlog/LightsIntensity/Gamma")]
        private static void luliFalse()
        {
            GraphicsSettings.lightsUseLinearIntensity = false;
            EditorSceneManager.SaveCurrentModifiedScenesIfUserWantsTo();
            var scn = EditorSceneManager.GetSceneManagerSetup();
            EditorSceneManager.OpenScene(scn[0].path);
        }
#endif
    }
}
