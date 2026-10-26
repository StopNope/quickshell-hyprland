precision mediump float;
varying vec2 v_texcoord;
uniform sampler2D tex;

void main() {
    vec4 pixColor = texture2D(tex, v_texcoord);
    // Warm night light filter (~4000K)
    pixColor.g *= 0.88;
    pixColor.b *= 0.62;
    gl_FragColor = pixColor;
}
