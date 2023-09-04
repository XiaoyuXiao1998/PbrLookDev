using UnityEditor;
using UnityEngine;
using UnityEngine.Experimental.Rendering;


[CreateAssetMenu(fileName = "Pbr Editor Asset", menuName = "Pbr Render Pipeline/Pbr Editor Asset", order = 0)]
public class EditorAsset : ScriptableObject {
	[Range(128, 1024)]
	public int iblLutResolution = 1024;
	public GraphicsFormat iblLutFormat = GraphicsFormat.R16G16B16A16_UNorm;
	public bool displayLutRefereces;
	public Texture referenceLut1;
	public Texture referenceLut2;
	public ComputeShader iblLutGenerationShader;
	


	public static bool AssetExistsAt(string path) {
		var guid = AssetDatabase.AssetPathToGUID(path);
		return !string.IsNullOrEmpty(guid);
	}

	public static void CreateOrOverrideAssetAt(Object asset, string path) {

		AssetDatabase.DeleteAsset(path);
		AssetDatabase.CreateAsset(asset, path);
	}

	public static void CreateAssetAt(Object asset, string path, bool overrideExistingAsset = false) {
		if (overrideExistingAsset) {
			CreateOrOverrideAssetAt(asset, path);
			return;
		}

		path = AssetDatabase.GenerateUniqueAssetPath(path);
		AssetDatabase.CreateAsset(asset, path);
	}
}
