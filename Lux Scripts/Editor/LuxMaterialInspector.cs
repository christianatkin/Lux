using System.Collections.Generic;
using UnityEngine;
using UnityEditor;
using System.Linq;

public class LuxMaterialInspector : MaterialEditor
{

    private bool orenNayarCheck;

    public override void OnInspectorGUI()
    {
        // render the default inspector
        base.OnInspectorGUI();

        // if we are not visible... return
        if (!isVisible)
            return;

        // get the current keywords from the material
        Material targetMat = target as Material;
        string[] keyWords = targetMat.shaderKeywords;

        // IBL settings
        bool diffCube = keyWords.Contains("DIFFCUBE_OFF");
        bool specCube = keyWords.Contains("SPECCUBE_OFF");
        bool ambientOcclusion = keyWords.Contains("LUX_AO_ON");
        bool orenNayarDiffuse = keyWords.Contains("LUX_OREN_NAYAR_ON");

        GUILayout.BeginVertical("box");
        GUILayout.Label("Customize Material");

        EditorGUI.BeginChangeCheck();
        EditorGUILayout.BeginHorizontal();

        // DiffCube
        diffCube = EditorGUILayout.Toggle("", diffCube, GUILayout.Width(14));
        EditorGUILayout.LabelField("Disable diffuse Cube IBL");
        EditorGUILayout.EndHorizontal();
        // SpecCube
        if (targetMat.HasProperty("_SpecCubeIBL"))
        {
            EditorGUILayout.BeginHorizontal();
            specCube = EditorGUILayout.Toggle("", specCube, GUILayout.Width(14));
            EditorGUILayout.LabelField("Disable specular Cube IBL");
            EditorGUILayout.EndHorizontal();
        }
        // AO
        if (targetMat.HasProperty("_AO"))
        {
            EditorGUILayout.BeginHorizontal();
            ambientOcclusion = EditorGUILayout.Toggle("", ambientOcclusion, GUILayout.Width(14));
            EditorGUILayout.LabelField("Enable Ambient Occlusion");
            EditorGUILayout.EndHorizontal();
            if (ambientOcclusion)
            {
                TextureProperty("_AO", "Ambient Occlusion (Alpha)", ShaderUtil.ShaderPropertyTexDim.TexDim2D);
            }
        }

        // Oren Nayar
        //if (targetMat.HasProperty("_OverallRoughness") && !Component.FindObjectOfType<SetupLux>().isOrenNayarGlobal)
        //{
        //    if(Camera.main.renderingPath != RenderingPath.DeferredLighting)
        //    {
        //        EditorGUILayout.BeginHorizontal();
        //        orenNayarCheck = EditorGUILayout.Toggle("", orenNayarCheck, GUILayout.Width(14));
        //        EditorGUILayout.LabelField("Enable Oren-Nayar Diffuse");
        //        EditorGUILayout.EndHorizontal();
        //        orenNayarDiffuse = orenNayarCheck;
        //    }
        //}
        //if (Component.FindObjectOfType<SetupLux>().isOrenNayarGlobal)
        //{
        //    EditorGUILayout.BeginHorizontal();
        //    EditorGUILayout.LabelField("Check SetupLux - Oren Nayar is global");
        //    EditorGUILayout.EndHorizontal();
        //    orenNayarDiffuse = true;
        //}
        if (targetMat.HasProperty("_OverallRoughness") && !targetMat.HasProperty("_Detail"))
        {
            RangeProperty("_DiffuseRoughness", "Diffuse Roughness", 0.0f, 1.0f);
            RangeProperty("_OverallRoughness", "Overall Roughness", 0.0f, 1.0f);
        }

        if (EditorGUI.EndChangeCheck())
        {
            var keywords = new List<string> { diffCube ? "DIFFCUBE_OFF" : "DIFFCUBE_ON" };
            if (specCube)
            {
                keywords.Add("SPECCUBE_OFF");
            }
            else if (targetMat.HasProperty("_SpecCubeIBL"))
            {
                keywords.Add("SPECCUBE_ON");
            }
            if (ambientOcclusion)
            {
                keywords.Add("LUX_AO_ON");
            }
            else
            {
                keywords.Add("LUX_AO_OFF");
            }
            if (orenNayarDiffuse)
            {
                keywords.Add("LUX_OREN_NAYAR_ON");
            }
            else
            {
                keywords.Add("LUX_OREN_NAYAR_OFF");
            }
            targetMat.shaderKeywords = keywords.ToArray();
            EditorUtility.SetDirty(targetMat);
        }
        GUILayout.EndVertical();
    }
}