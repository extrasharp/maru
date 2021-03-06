const std = @import("std");
const Allocator = std.mem.Allocator;
const json = std.json;
const StringHashMap = std.StringHashMap;

//;

const c = @import("c.zig");
const math = @import("math.zig");
usingnamespace math;

//;

// glfw parser thing
//   parse the base64 buffers to u8 buffer

// for default 3d utils
//   have 3d mesh
//   materials
//   animations
//     skeletal and morph
//       skeletal: vertex shader
//       morph: also in vertex shader?
//     default animated shader

// TODO uri type?
// get rid of all float cast and int cast in here and just use i64 and f64?

//;

fn jsonValueDeepClone(allocator: *Allocator, j: json.Value) Allocator.Error!json.Value {
    switch (j) {
        .Null => return json.Value.Null,
        .Bool => |val| return json.Value{ .Bool = val },
        .Integer => |val| return json.Value{ .Integer = val },
        .Float => |val| return json.Value{ .Float = val },
        .String => |val| return json.Value{ .String = try allocator.dupe(u8, val) },
        .Array => |val| {
            var arr = try json.Array.initCapacity(allocator, val.items.len);
            for (val.items) |i| {
                try arr.append(try jsonValueDeepClone(allocator, i));
            }
            return json.Value{ .Array = arr };
        },
        .Object => |val| {
            var ht = json.ObjectMap.init(allocator);
            var iter = val.iterator();
            while (iter.next()) |entry| {
                try ht.put(entry.key, try jsonValueDeepClone(allocator, entry.value));
            }
            return json.Value{ .Object = ht };
        },
    }
}

fn jsonValueFreeClone(allocator: *Allocator, j: *json.Value) void {
    switch (j.*) {
        .String => |val| allocator.free(val),
        .Array => |*val| {
            for (val.items) |*i| {
                jsonValueFreeClone(allocator, i);
            }
            val.deinit();
        },
        .Object => |*val| {
            var iter = val.iterator();
            while (iter.next()) |entry| {
                jsonValueFreeClone(allocator, &entry.value);
            }
            val.deinit();
        },
        else => {},
    }
}

fn jsonValueToFloat(comptime T: type, j: json.Value) T {
    return switch (j) {
        .Float => |f| @floatCast(T, f),
        .Integer => |i| @intToFloat(T, i),
        // TODO this is probably okay as unreachable
        else => unreachable,
    };
}

//;

pub const Accessor = struct {
    pub const ComponentType = enum(c.GLenum) {
        Byte = c.GL_BYTE,
        UnsignedByte = c.GL_UNSIGNED_BYTE,
        Short = c.GL_SHORT,
        UnsignedShort = c.GL_UNSIGNED_SHORT,
        UnsignedInt = c.GL_UNSIGNED_INT,
        Float = c.GL_FLOAT,
    };

    pub const DataType = enum {
        Scalar,
        Vec2,
        Vec3,
        Vec4,
        Mat2,
        Mat3,
        Mat4,
    };

    buffer_view: ?usize = null,
    byte_offset: ?usize = 0,
    component_type: ComponentType,
    normalized: ?bool = false,
    count: usize,
    data_type: DataType,
    // TODO min max
    // TODO sparse
    name: ?[]u8 = null,
    extensions: ?Extensions = null,
    extras: ?Extras = null,
};

// TODO animation

pub const Asset = struct {
    copyright: ?[]u8 = null,
    generator: ?[]u8 = null,
    version: []const u8,
    min_version: ?[]u8 = null,
    extensions: ?Extensions = null,
    extras: ?Extras = null,
};

pub const Buffer = struct {
    uri: ?[]u8 = null,
    byte_length: usize,
    name: ?[]u8 = null,
    extensions: ?Extensions = null,
    extras: ?Extras = null,
};

pub const BufferView = struct {
    pub const Target = enum(c.GLenum) {
        ArrayBuffer = c.GL_ARRAY_BUFFER,
        ElementArrayBuffer = c.GL_ELEMENT_ARRAY_BUFFER,
    };

    buffer: usize,
    byte_offset: ?usize = 0,
    byte_length: usize,
    byte_stride: ?usize = null,
    target: ?Target = null,
    name: ?[]u8 = null,
    extensions: ?Extensions = null,
    extras: ?Extras = null,
};

pub const Camera = struct {
    pub const CameraType = enum {
        Orthographic,
        Perspective,
    };

    orthographic: ?Orthographic = null,
    perspective: ?Perspective = null,
    camera_type: ?CameraType = null,
    name: ?[]u8 = null,
    extensions: ?Extensions = null,
    extras: ?Extras = null,
};

// TODO channel

pub const Extensions = json.Value;
pub const Extras = json.Value;

pub const Image = struct {
    pub const MimeType = enum {
        JPEG,
        PNG,
    };

    uri: ?[]u8 = null,
    buffer_view: ?usize = null,
    mime_type: ?MimeType = null,
    name: ?[]u8 = null,
    extensions: ?Extensions = null,
    extras: ?Extras = null,
};

// sparse indices

pub const Material = struct {
    pub const AlphaMode = enum {
        Opaque,
        Mask,
        Blend,
    };

    pbr_metallic_roughness: ?PbrMetallicRoughness = .{},
    normal_texture: ?NormalTextureInfo = null,
    occlusion_texture: ?OcclusionTextureInfo = null,
    emissive_texture: ?TextureInfo = null,
    emissive_factor: ?Color = Color.black(),
    alpha_mode: ?AlphaMode = .Opaque,
    alpha_cutoff: ?f32 = 0.5,
    double_sided: ?bool = false,
    name: ?[]u8 = null,
    extensions: ?Extensions = null,
    extras: ?Extras = null,
};

pub const Mesh = struct {
    primitives: []Primitive,
    weights: ?[]f32 = null,
    name: ?[]u8 = null,
    extensions: ?Extensions = null,
    extras: ?Extras = null,
};

pub const Node = struct {
    camera: ?usize = null,
    children: ?[]usize = null,
    // TODO skin
    matrix: ?Mat4 = Mat4.identity(),
    mesh: ?usize = null,
    rotation: ?Quaternion = Quaternion.identity(),
    scale: ?Vec3 = Vec3.one(),
    translation: ?Vec3 = Vec3.zero(),
    // TODO weights
    name: ?[]u8 = null,
    extensions: ?Extensions = null,
    extras: ?Extras = null,
};

pub const NormalTextureInfo = struct {
    index: usize,
    tex_coord: ?usize = 0,
    scale: ?f32 = 1,
    extensions: ?Extensions = null,
    extras: ?Extras = null,
};

pub const OcclusionTextureInfo = struct {
    index: usize,
    tex_coord: ?usize = 0,
    strength: ?f32 = 1,
    extensions: ?Extensions = null,
    extras: ?Extras = null,
};

pub const Orthographic = struct {
    xmag: f32,
    ymag: f32,
    zfar: f32,
    znear: f32,
    extensions: ?Extensions = null,
    extras: ?Extras = null,
};

pub const PbrMetallicRoughness = struct {
    base_color_factor: ?Color = Color.white(),
    base_color_texture: ?TextureInfo = null,
    metallic_factor: ?f32 = 1,
    roughness_factor: ?f32 = 1,
    metallic_roughness_texture: ?TextureInfo = null,
    extensions: ?Extensions = null,
    extras: ?Extras = null,
};

pub const Perspective = struct {
    aspect_ratio: ?f32 = null,
    yfov: f32,
    zfar: ?f32 = null,
    znear: f32,
    extensions: ?Extensions = null,
    extras: ?Extras = null,
};

pub const Primitive = struct {
    pub const AttributeMap = StringHashMap(usize);

    pub const Mode = enum(c.GLenum) {
        Points = c.GL_POINTS,
        Lines = c.GL_LINES,
        LineLoop = c.GL_LINE_LOOP,
        LineStrip = c.GL_LINE_STRIP,
        Triangles = c.GL_TRIANGLES,
        TriangleStrip = c.GL_TRIANGLE_STRIP,
        TriangleFan = c.GL_TRIANGLE_FAN,
    };

    attributes: AttributeMap,
    indices: ?usize = null,
    material: ?usize = null,
    mode: ?Mode = .Triangles,
    targets: ?[]AttributeMap = null,
    extensions: ?Extensions = null,
    extras: ?Extras = null,
};

pub const Sampler = struct {
    pub const Filter = enum(c.GLenum) {
        Nearest = c.GL_NEAREST,
        Linear = c.GL_LINEAR,
        NearestMipmapNearest = c.GL_NEAREST_MIPMAP_NEAREST,
        LinearMipmapNearest = c.GL_LINEAR_MIPMAP_NEAREST,
        NearestMipmapLinear = c.GL_NEAREST_MIPMAP_LINEAR,
        LinearMipmapLinear = c.GL_LINEAR_MIPMAP_LINEAR,
    };

    pub const Wrap = enum(c.GLenum) {
        ClampToEdge = c.GL_CLAMP_TO_EDGE,
        MirroredRepeat = c.GL_MIRRORED_REPEAT,
        Repeat = c.GL_REPEAT,
    };

    mag_filter: ?Filter = null,
    min_filter: ?Filter = null,
    wrap_s: ?Wrap = .Repeat,
    wrap_t: ?Wrap = .Repeat,
    name: ?[]u8 = null,
    extensions: ?Extensions = null,
    extras: ?Extras = null,
};

pub const Scene = struct {
    nodes: ?[]usize = null,
    name: ?[]u8 = null,
    extensions: ?Extensions = null,
    extras: ?Extras = null,
};

// TODO skin
// TODO sparse
// TODO target

pub const Texture = struct {
    source: ?usize = null,
    sampler: ?usize = null,
    name: ?[]u8 = null,
    extensions: ?Extensions = null,
    extras: ?Extras = null,
};

pub const TextureInfo = struct {
    index: usize,
    tex_coord: ?usize = 0,
    extensions: ?Extensions = null,
    extras: ?Extras = null,
};

// TODO sparse values

//;

pub const GlTF = struct {
    extensions_used: ?[][]u8 = null,
    extensions_required: ?[][]u8 = null,
    accessors: ?[]Accessor = null,
    // animations
    asset: Asset,
    buffers: ?[]Buffer = null,
    buffer_views: ?[]BufferView = null,
    cameras: ?[]Camera = null,
    images: ?[]Image = null,
    materials: ?[]Material = null,
    meshes: ?[]Mesh = null,
    nodes: ?[]Node = null,
    samplers: ?[]Sampler = null,
    scene: ?usize = null,
    scenes: ?[]Scene = null,
    // skins
    textures: ?[]Texture = null,
    extensions: ?Extensions = null,
    extras: ?Extras = null,
};

//;

pub const GlTF_Parser = struct {
    const Self = @This();

    pub const Error = error{
        AssetInfoNotFound,
        NoVersionSpecified,
        GlTF_VersionNotSupported,
        InvalidAccessor,
        InvalidBuffer,
        InvalidBufferView,
        InvalidCamera,
        InvalidImage,
        InvalidMaterial,
        InvalidMesh,
    };

    allocator: *Allocator,
    parser: json.Parser,

    pub fn init(allocator: *Allocator) Self {
        return .{
            .allocator = allocator,
            .parser = json.Parser.init(allocator, false),
        };
    }

    pub fn deinit(self: *Self) void {
        self.parser.deinit();
    }

    //;

    pub fn parseFromString(self: *Self, input: []const u8) !GlTF {
        var j = try self.parser.parse(input);
        defer j.deinit();

        const root = j.root;

        // TODO better error handling for if json objects arent the right type?
        // not a big deal as long as user cant supply thier own assets

        const j_asset = root.Object.get("asset") orelse return Error.AssetInfoNotFound;
        const version = j_asset.Object.get("version") orelse return Error.NoVersionSpecified;
        if (!std.mem.eql(u8, version.String, "2.0")) return Error.GlTF_VersionNotSupported;

        var ret = GlTF{
            .asset = .{
                .version = try self.allocator.dupe(u8, version.String),
            },
        };

        // TODO
        if (root.Object.get("extensionsUsed")) |exts| {}
        if (root.Object.get("extensionsRequired")) |exts| {}

        try parseAsset(self, &ret, j_asset);
        if (root.Object.get("accessors")) |jv| {
            try self.parseAccessors(&ret, jv);
        }
        if (root.Object.get("buffers")) |jv| {
            try self.parseBuffers(&ret, jv);
        }
        if (root.Object.get("bufferViews")) |jv| {
            try self.parseBufferViews(&ret, jv);
        }
        if (root.Object.get("cameras")) |jv| {
            try self.parseCameras(&ret, jv);
        }
        if (root.Object.get("images")) |jv| {
            try self.parseImages(&ret, jv);
        }
        if (root.Object.get("materials")) |jv| {
            try self.parseMaterials(&ret, jv);
        }
        if (root.Object.get("meshes")) |jv| {
            try self.parseMeshes(&ret, jv);
        }
        if (root.Object.get("nodes")) |jv| {
            try self.parseNodes(&ret, jv);
        }
        if (root.Object.get("samplers")) |jv| {
            try self.parseSamplers(&ret, jv);
        }
        if (root.Object.get("scene")) |jv| {
            ret.scene = @intCast(usize, jv.Integer);
        }
        if (root.Object.get("scenes")) |jv| {
            try self.parseScenes(&ret, jv);
        }
        if (root.Object.get("textures")) |jv| {
            try self.parseTextures(&ret, jv);
        }
        if (root.Object.get("extensions")) |jv| {
            ret.extensions = try jsonValueDeepClone(self.allocator, jv);
        }
        if (root.Object.get("extras")) |jv| {
            ret.extras = try jsonValueDeepClone(self.allocator, jv);
        }

        return ret;
    }

    pub fn freeParse(self: *Self, gltf: *GlTF) void {
        self.freeAsset(gltf);
        self.freeAccessors(gltf);
        self.freeBuffers(gltf);
        self.freeBufferViews(gltf);
        self.freeCameras(gltf);
        self.freeImages(gltf);
        self.freeMaterials(gltf);
        self.freeMeshes(gltf);
        self.freeNodes(gltf);
        self.freeSamplers(gltf);
        self.freeScenes(gltf);
        self.freeTextures(gltf);
        if (gltf.extensions) |*ext| jsonValueFreeClone(self.allocator, ext);
        if (gltf.extras) |*ext| jsonValueFreeClone(self.allocator, ext);
    }

    //;

    // TODO take *Asset not *GlTF
    fn parseAsset(self: *Self, gltf: *GlTF, j_val: json.Value) !void {
        // TODO handle memory leaks
        if (j_val.Object.get("copyright")) |jv| {
            gltf.asset.copyright = try self.allocator.dupe(u8, jv.String);
        }
        if (j_val.Object.get("generator")) |jv| {
            gltf.asset.generator = try self.allocator.dupe(u8, jv.String);
        }
        if (j_val.Object.get("minVersion")) |jv| {
            gltf.asset.min_version = try self.allocator.dupe(u8, jv.String);
        }
        if (j_val.Object.get("extensions")) |jv| {
            gltf.asset.extensions = try jsonValueDeepClone(self.allocator, jv);
        }
        if (j_val.Object.get("extras")) |jv| {
            gltf.asset.extras = try jsonValueDeepClone(self.allocator, jv);
        }
    }

    fn freeAsset(self: *Self, gltf: *GlTF) void {
        self.allocator.free(gltf.asset.version);
        if (gltf.asset.copyright) |str| self.allocator.free(str);
        if (gltf.asset.generator) |str| self.allocator.free(str);
        if (gltf.asset.min_version) |str| self.allocator.free(str);
        if (gltf.asset.extensions) |*ext| jsonValueFreeClone(self.allocator, ext);
        if (gltf.asset.extras) |*ext| jsonValueFreeClone(self.allocator, ext);
    }

    fn parseAccessors(self: *Self, gltf: *GlTF, j_val: json.Value) !void {
        const len = j_val.Array.items.len;
        gltf.accessors = try self.allocator.alloc(Accessor, len);

        for (j_val.Array.items) |jv, i| {
            const gl_type = jv.Object.get("componentType") orelse return Error.InvalidAccessor;
            const count = jv.Object.get("count") orelse return Error.InvalidAccessor;
            const data_type_str = (jv.Object.get("type") orelse return Error.InvalidAccessor).String;
            const data_type = if (std.mem.eql(u8, data_type_str, "SCALAR")) blk: {
                break :blk Accessor.DataType.Scalar;
            } else if (std.mem.eql(u8, data_type_str, "VEC2")) blk: {
                break :blk Accessor.DataType.Vec2;
            } else if (std.mem.eql(u8, data_type_str, "VEC3")) blk: {
                break :blk Accessor.DataType.Vec3;
            } else if (std.mem.eql(u8, data_type_str, "VEC4")) blk: {
                break :blk Accessor.DataType.Vec4;
            } else if (std.mem.eql(u8, data_type_str, "MAT2")) blk: {
                break :blk Accessor.DataType.Mat2;
            } else if (std.mem.eql(u8, data_type_str, "MAT3")) blk: {
                break :blk Accessor.DataType.Mat3;
            } else if (std.mem.eql(u8, data_type_str, "MAT4")) blk: {
                break :blk Accessor.DataType.Mat4;
            } else {
                return Error.InvalidAccessor;
            };

            var curr = &gltf.accessors.?[i];
            curr.* = .{
                .component_type = @intToEnum(Accessor.ComponentType, @intCast(c.GLenum, gl_type.Integer)),
                .count = @intCast(usize, count.Integer),
                .data_type = data_type,
            };

            if (jv.Object.get("bufferView")) |jv_| {
                curr.buffer_view = @intCast(usize, jv_.Integer);
            }
            if (jv.Object.get("byteOffset")) |jv_| {
                curr.byte_offset = @intCast(usize, jv_.Integer);
            }
            if (jv.Object.get("normalized")) |jv_| {
                curr.normalized = jv_.Bool;
            }
            if (jv.Object.get("name")) |jv_| {
                curr.name = try self.allocator.dupe(u8, jv_.String);
            }
            if (jv.Object.get("extensions")) |jv_| {
                curr.extensions = try jsonValueDeepClone(self.allocator, jv_);
            }
            if (jv.Object.get("extras")) |jv_| {
                curr.extras = try jsonValueDeepClone(self.allocator, jv_);
            }
        }
    }

    fn freeAccessors(self: *Self, gltf: *GlTF) void {
        if (gltf.accessors) |objs| {
            for (objs) |*obj| {
                if (obj.name) |name| self.allocator.free(name);
                if (obj.extensions) |*jv| jsonValueFreeClone(self.allocator, jv);
                if (obj.extras) |*jv| jsonValueFreeClone(self.allocator, jv);
            }
            self.allocator.free(objs);
        }
    }

    fn parseBuffers(self: *Self, gltf: *GlTF, j_val: json.Value) !void {
        const len = j_val.Array.items.len;
        gltf.buffers = try self.allocator.alloc(Buffer, len);

        for (j_val.Array.items) |jv, i| {
            const byte_length = jv.Object.get("byteLength") orelse return Error.InvalidBuffer;

            var curr = &gltf.buffers.?[i];
            curr.* = .{
                .byte_length = @intCast(usize, byte_length.Integer),
            };

            if (jv.Object.get("uri")) |jv_| {
                curr.uri = try self.allocator.dupe(u8, jv_.String);
            }
            if (jv.Object.get("name")) |jv_| {
                curr.name = try self.allocator.dupe(u8, jv_.String);
            }
            if (jv.Object.get("extensions")) |jv_| {
                curr.extensions = try jsonValueDeepClone(self.allocator, jv_);
            }
            if (jv.Object.get("extras")) |jv_| {
                curr.extras = try jsonValueDeepClone(self.allocator, jv_);
            }
        }
    }

    fn freeBuffers(self: *Self, gltf: *GlTF) void {
        if (gltf.buffers) |objs| {
            for (objs) |*obj| {
                if (obj.uri) |uri| self.allocator.free(uri);
                if (obj.name) |name| self.allocator.free(name);
                if (obj.extensions) |*ext| jsonValueFreeClone(self.allocator, ext);
                if (obj.extras) |*ext| jsonValueFreeClone(self.allocator, ext);
            }
            self.allocator.free(objs);
        }
    }

    fn parseBufferViews(self: *Self, gltf: *GlTF, j_val: json.Value) !void {
        const len = j_val.Array.items.len;
        gltf.buffer_views = try self.allocator.alloc(BufferView, len);

        for (j_val.Array.items) |jv, i| {
            const buffer = jv.Object.get("buffer") orelse return Error.InvalidBufferView;
            const byte_length = jv.Object.get("byteLength") orelse return Error.InvalidBufferView;

            var curr = &gltf.buffer_views.?[i];
            curr.* = .{
                .buffer = @intCast(usize, buffer.Integer),
                .byte_length = @intCast(usize, byte_length.Integer),
            };

            if (jv.Object.get("byteOffset")) |jv_| {
                curr.byte_offset = @intCast(usize, jv_.Integer);
            }
            if (jv.Object.get("byteStride")) |jv_| {
                curr.byte_stride = @intCast(usize, jv_.Integer);
            }
            if (jv.Object.get("target")) |jv_| {
                curr.target = @intToEnum(BufferView.Target, @intCast(c.GLenum, jv_.Integer));
            }
            if (jv.Object.get("name")) |jv_| {
                curr.name = try self.allocator.dupe(u8, jv_.String);
            }
            if (jv.Object.get("extensions")) |jv_| {
                curr.extensions = try jsonValueDeepClone(self.allocator, jv_);
            }
            if (jv.Object.get("extras")) |jv_| {
                curr.extras = try jsonValueDeepClone(self.allocator, jv_);
            }
        }
    }

    fn freeBufferViews(self: *Self, gltf: *GlTF) void {
        if (gltf.buffer_views) |objs| {
            for (objs) |*obj| {
                if (obj.name) |name| self.allocator.free(name);
                if (obj.extensions) |*jv| jsonValueFreeClone(self.allocator, jv);
                if (obj.extras) |*jv| jsonValueFreeClone(self.allocator, jv);
            }
            self.allocator.free(objs);
        }
    }

    fn parseCameras(self: *Self, gltf: *GlTF, j_array: json.Value) !void {
        const len = j_array.Array.items.len;
        gltf.cameras = try self.allocator.alloc(Camera, len);

        for (j_array.Array.items) |jv, i| {
            var curr = &gltf.cameras.?[i];
            curr.* = .{};

            if (jv.Object.get("type")) |jv_| {
                const str = jv_.String;
                if (std.mem.eql(u8, str, "orthographic")) {
                    curr.camera_type = .Orthographic;
                } else if (std.mem.eql(u8, str, "perspective")) {
                    curr.camera_type = .Perspective;
                } else {
                    return Error.InvalidCamera;
                }
            }
            if (jv.Object.get("orthographic")) |jv_| {
                try self.parseOrthographic(&curr.orthographic, jv_);
            }
            if (jv.Object.get("perspective")) |jv_| {
                try self.parsePerspective(&curr.perspective, jv_);
            }
            if (jv.Object.get("name")) |jv_| {
                curr.name = try self.allocator.dupe(u8, jv_.String);
            }
            if (jv.Object.get("extensions")) |jv_| {
                curr.extensions = try jsonValueDeepClone(self.allocator, jv_);
            }
            if (jv.Object.get("extras")) |jv_| {
                curr.extras = try jsonValueDeepClone(self.allocator, jv_);
            }
        }
    }

    fn freeCameras(self: *Self, gltf: *GlTF) void {
        if (gltf.cameras) |objs| {
            for (objs) |*obj| {
                if (obj.orthographic) |*data| self.freeOrthographic(data);
                if (obj.perspective) |*data| self.freePerspective(data);
                if (obj.name) |name| self.allocator.free(name);
                if (obj.extensions) |*jv| jsonValueFreeClone(self.allocator, jv);
                if (obj.extras) |*jv| jsonValueFreeClone(self.allocator, jv);
            }
            self.allocator.free(objs);
        }
    }

    fn parseImages(self: *Self, gltf: *GlTF, j_array: json.Value) !void {
        const len = j_array.Array.items.len;
        gltf.images = try self.allocator.alloc(Image, len);

        for (j_array.Array.items) |jv, i| {
            var curr = &gltf.images.?[i];
            curr.* = .{};

            if (jv.Object.get("uri")) |jv_| {
                curr.uri = try self.allocator.dupe(u8, jv_.String);
            }
            if (jv.Object.get("bufferView")) |jv_| {
                curr.buffer_view = @intCast(usize, jv_.Integer);
            }
            if (jv.Object.get("mimeType")) |jv_| {
                const str = jv_.String;
                if (std.mem.eql(u8, str, "image/jpeg")) {
                    curr.mime_type = .JPEG;
                } else if (std.mem.eql(u8, str, "image/png")) {
                    curr.mime_type = .PNG;
                } else {
                    return Error.InvalidImage;
                }
            }
            if (jv.Object.get("name")) |jv_| {
                curr.name = try self.allocator.dupe(u8, jv_.String);
            }
            if (jv.Object.get("extensions")) |jv_| {
                curr.extensions = try jsonValueDeepClone(self.allocator, jv_);
            }
            if (jv.Object.get("extras")) |jv_| {
                curr.extras = try jsonValueDeepClone(self.allocator, jv_);
            }
        }
    }

    fn freeImages(self: *Self, gltf: *GlTF) void {
        if (gltf.images) |objs| {
            for (objs) |*obj| {
                if (obj.uri) |uri| self.allocator.free(uri);
                if (obj.name) |name| self.allocator.free(name);
                if (obj.extensions) |*jv| jsonValueFreeClone(self.allocator, jv);
                if (obj.extras) |*jv| jsonValueFreeClone(self.allocator, jv);
            }
            self.allocator.free(objs);
        }
    }

    fn parseMaterials(self: *Self, gltf: *GlTF, j_array: json.Value) !void {
        const len = j_array.Array.items.len;
        gltf.materials = try self.allocator.alloc(Material, len);

        for (j_array.Array.items) |jv, i| {
            var curr = &gltf.materials.?[i];
            curr.* = .{};

            if (jv.Object.get("pbrMetallicRoughness")) |jv_| {
                try self.parsePbrMetallicRoughness(&curr.pbr_metallic_roughness, jv_);
            }
            if (jv.Object.get("normalTexture")) |jv_| {
                try self.parseNormalTextureInfo(&curr.normal_texture, jv_);
            }
            if (jv.Object.get("occlusionTexture")) |jv_| {
                try self.parseOcclusionTextureInfo(&curr.occlusion_texture, jv_);
            }
            if (jv.Object.get("emissiveTexture")) |jv_| {
                try self.parseTextureInfo(&curr.emissive_texture, jv_);
            }
            if (jv.Object.get("emissiveFactor")) |jv_| {
                curr.emissive_factor.?.r = jsonValueToFloat(f32, jv_.Array.items[0]);
                curr.emissive_factor.?.g = jsonValueToFloat(f32, jv_.Array.items[1]);
                curr.emissive_factor.?.b = jsonValueToFloat(f32, jv_.Array.items[2]);
                curr.emissive_factor.?.a = jsonValueToFloat(f32, jv_.Array.items[3]);
            }
            if (jv.Object.get("alphaMode")) |jv_| {
                if (std.mem.eql(u8, jv_.String, "OPAQUE")) {
                    curr.alpha_mode = .Opaque;
                } else if (std.mem.eql(u8, jv_.String, "MASK")) {
                    curr.alpha_mode = .Mask;
                } else if (std.mem.eql(u8, jv_.String, "BLEND")) {
                    curr.alpha_mode = .Blend;
                } else {
                    return Error.InvalidMaterial;
                }
            }
            if (jv.Object.get("alphaCutoff")) |jv_| {
                curr.alpha_cutoff = jsonValueToFloat(f32, jv_);
            }
            if (jv.Object.get("doubleSided")) |jv_| {
                curr.double_sided = jv_.Bool;
            }
            if (jv.Object.get("name")) |jv_| {
                curr.name = try self.allocator.dupe(u8, jv_.String);
            }
            if (jv.Object.get("extensions")) |jv_| {
                curr.extensions = try jsonValueDeepClone(self.allocator, jv_);
            }
            if (jv.Object.get("extras")) |jv_| {
                curr.extras = try jsonValueDeepClone(self.allocator, jv_);
            }
        }
    }

    fn freeMaterials(self: *Self, gltf: *GlTF) void {
        if (gltf.materials) |objs| {
            for (objs) |*obj| {
                if (obj.pbr_metallic_roughness) |*pbr| self.freePbrMetallicRoughness(pbr);
                if (obj.normal_texture) |*nti| self.freeNormalTextureInfo(nti);
                if (obj.occlusion_texture) |*oti| self.freeOcclusionTextureInfo(oti);
                if (obj.emissive_texture) |*eti| self.freeTextureInfo(eti);
                if (obj.name) |name| self.allocator.free(name);
                if (obj.extensions) |*jv| jsonValueFreeClone(self.allocator, jv);
                if (obj.extras) |*jv| jsonValueFreeClone(self.allocator, jv);
            }
            self.allocator.free(objs);
        }
    }

    fn parseMeshes(self: *Self, gltf: *GlTF, j_array: json.Value) !void {
        const len = j_array.Array.items.len;
        gltf.meshes = try self.allocator.alloc(Mesh, len);

        for (j_array.Array.items) |jv, i| {
            const primitives = jv.Object.get("primitives") orelse return Error.InvalidMesh;
            var curr = &gltf.meshes.?[i];
            curr.* = .{
                .primitives = try self.allocator.alloc(Primitive, primitives.Array.items.len),
            };
            for (primitives.Array.items) |jv_, pi| {
                try self.parsePrimitive(&curr.primitives[pi], jv_);
            }

            if (jv.Object.get("weights")) |jv_| {
                curr.weights = try self.allocator.alloc(f32, jv_.Array.items.len);
                for (jv_.Array.items) |weight, wi| {
                    curr.weights.?[wi] = jsonValueToFloat(f32, weight);
                }
            }
            if (jv.Object.get("name")) |jv_| {
                curr.name = try self.allocator.dupe(u8, jv_.String);
            }
            if (jv.Object.get("extensions")) |jv_| {
                curr.extensions = try jsonValueDeepClone(self.allocator, jv_);
            }
            if (jv.Object.get("extras")) |jv_| {
                curr.extras = try jsonValueDeepClone(self.allocator, jv_);
            }
        }
    }

    fn freeMeshes(self: *Self, gltf: *GlTF) void {
        if (gltf.meshes) |objs| {
            for (objs) |*obj| {
                for (obj.primitives) |*p| {
                    self.freePrimitive(p);
                    self.allocator.free(obj.primitives);
                }
                if (obj.weights) |weights| self.allocator.free(weights);
                if (obj.name) |name| self.allocator.free(name);
                if (obj.extensions) |*jv| jsonValueFreeClone(self.allocator, jv);
                if (obj.extras) |*jv| jsonValueFreeClone(self.allocator, jv);
            }
            self.allocator.free(objs);
        }
    }

    fn parseNodes(self: *Self, gltf: *GlTF, j_array: json.Value) !void {
        const len = j_array.Array.items.len;
        gltf.nodes = try self.allocator.alloc(Node, len);

        for (j_array.Array.items) |jv, i| {
            var curr = &gltf.nodes.?[i];
            curr.* = .{};
            if (jv.Object.get("camera")) |jv_| {
                curr.camera = @intCast(usize, jv_.Integer);
            }
            if (jv.Object.get("children")) |jv_| {
                curr.children = try self.allocator.alloc(usize, jv_.Array.items.len);
                for (jv_.Array.items) |jv__, ci| {
                    curr.children.?[ci] = @intCast(usize, jv__.Integer);
                }
            }
            if (jv.Object.get("matrix")) |jv_| {
                curr.matrix = Mat4.identity();
                for (jv_.Array.items) |item, ai| {
                    const y = ai % 4;
                    const x = ai / 4;
                    curr.matrix.?.data[y][x] = jsonValueToFloat(f32, item);
                }
            }
            if (jv.Object.get("mesh")) |jv_| {
                curr.mesh = @intCast(usize, jv_.Integer);
            }
            if (jv.Object.get("rotation")) |jv_| {
                curr.rotation = Quaternion.identity();
                curr.rotation.?.x = jsonValueToFloat(f32, jv_.Array.items[0]);
                curr.rotation.?.y = jsonValueToFloat(f32, jv_.Array.items[1]);
                curr.rotation.?.z = jsonValueToFloat(f32, jv_.Array.items[2]);
                curr.rotation.?.w = jsonValueToFloat(f32, jv_.Array.items[3]);
            }
            if (jv.Object.get("scale")) |jv_| {
                curr.scale = Vec3.one();
                curr.scale.?.x = jsonValueToFloat(f32, jv_.Array.items[0]);
                curr.scale.?.y = jsonValueToFloat(f32, jv_.Array.items[1]);
                curr.scale.?.z = jsonValueToFloat(f32, jv_.Array.items[2]);
            }
            if (jv.Object.get("translation")) |jv_| {
                curr.translation = Vec3.zero();
                curr.translation.?.x = jsonValueToFloat(f32, jv_.Array.items[0]);
                curr.translation.?.y = jsonValueToFloat(f32, jv_.Array.items[1]);
                curr.translation.?.z = jsonValueToFloat(f32, jv_.Array.items[2]);
            }
            if (jv.Object.get("name")) |jv_| {
                curr.name = try self.allocator.dupe(u8, jv_.String);
            }
            if (jv.Object.get("extensions")) |jv_| {
                curr.extensions = try jsonValueDeepClone(self.allocator, jv_);
            }
            if (jv.Object.get("extras")) |jv_| {
                curr.extras = try jsonValueDeepClone(self.allocator, jv_);
            }
        }
    }

    fn freeNodes(self: *Self, gltf: *GlTF) void {
        if (gltf.nodes) |objs| {
            for (objs) |*obj| {
                if (obj.children) |chl| self.allocator.free(chl);
                if (obj.name) |name| self.allocator.free(name);
                if (obj.extensions) |*jv| jsonValueFreeClone(self.allocator, jv);
                if (obj.extras) |*jv| jsonValueFreeClone(self.allocator, jv);
            }
            self.allocator.free(objs);
        }
    }

    fn parseNormalTextureInfo(self: *Self, data: *?NormalTextureInfo, jv: json.Value) !void {
        const index = jv.Object.get("index") orelse return Error.InvalidMaterial;
        data.* = .{
            .index = @intCast(usize, index.Integer),
        };

        if (jv.Object.get("texCoord")) |jv_| {
            data.*.?.tex_coord = @intCast(usize, jv_.Integer);
        }
        if (jv.Object.get("scale")) |jv_| {
            data.*.?.scale = jsonValueToFloat(f32, jv_);
        }
        if (jv.Object.get("extensions")) |jv_| {
            data.*.?.extensions = try jsonValueDeepClone(self.allocator, jv_);
        }
        if (jv.Object.get("extras")) |jv_| {
            data.*.?.extras = try jsonValueDeepClone(self.allocator, jv_);
        }
    }

    fn freeNormalTextureInfo(self: *Self, data: *NormalTextureInfo) void {
        if (data.extensions) |*jv| jsonValueFreeClone(self.allocator, jv);
        if (data.extras) |*jv| jsonValueFreeClone(self.allocator, jv);
    }

    fn parseOcclusionTextureInfo(self: *Self, data: *?OcclusionTextureInfo, jv: json.Value) !void {
        const index = jv.Object.get("index") orelse return Error.InvalidMaterial;
        data.* = .{
            .index = @intCast(usize, index.Integer),
        };

        if (jv.Object.get("texCoord")) |jv_| {
            data.*.?.tex_coord = @intCast(usize, jv_.Integer);
        }
        if (jv.Object.get("strength")) |jv_| {
            data.*.?.strength = jsonValueToFloat(f32, jv_);
        }
        if (jv.Object.get("extensions")) |jv_| {
            data.*.?.extensions = try jsonValueDeepClone(self.allocator, jv_);
        }
        if (jv.Object.get("extras")) |jv_| {
            data.*.?.extras = try jsonValueDeepClone(self.allocator, jv_);
        }
    }

    fn freeOcclusionTextureInfo(self: *Self, data: *OcclusionTextureInfo) void {
        if (data.extensions) |*jv| jsonValueFreeClone(self.allocator, jv);
        if (data.extras) |*jv| jsonValueFreeClone(self.allocator, jv);
    }

    fn parseOrthographic(self: *Self, data: *?Orthographic, jv: json.Value) !void {
        const xmag = jv.Object.get("xmag") orelse return Error.InvalidCamera;
        const ymag = jv.Object.get("ymag") orelse return Error.InvalidCamera;
        const zfar = jv.Object.get("zfar") orelse return Error.InvalidCamera;
        const znear = jv.Object.get("znear") orelse return Error.InvalidCamera;
        data.* = .{
            .xmag = jsonValueToFloat(f32, xmag),
            .ymag = jsonValueToFloat(f32, ymag),
            .zfar = jsonValueToFloat(f32, zfar),
            .znear = jsonValueToFloat(f32, znear),
        };
        if (jv.Object.get("extensions")) |jv_| {
            data.*.?.extensions = try jsonValueDeepClone(self.allocator, jv_);
        }
        if (jv.Object.get("extras")) |jv_| {
            data.*.?.extras = try jsonValueDeepClone(self.allocator, jv_);
        }
    }

    fn freeOrthographic(self: *Self, data: *Orthographic) void {
        if (data.extensions) |*jv| jsonValueFreeClone(self.allocator, jv);
        if (data.extras) |*jv| jsonValueFreeClone(self.allocator, jv);
    }

    fn parsePbrMetallicRoughness(self: *Self, data: *?PbrMetallicRoughness, jv: json.Value) !void {
        data.* = .{};

        if (jv.Object.get("baseColorFactor")) |jv_| {
            data.*.?.base_color_factor.?.r = jsonValueToFloat(f32, jv_.Array.items[0]);
            data.*.?.base_color_factor.?.g = jsonValueToFloat(f32, jv_.Array.items[1]);
            data.*.?.base_color_factor.?.b = jsonValueToFloat(f32, jv_.Array.items[2]);
            data.*.?.base_color_factor.?.a = jsonValueToFloat(f32, jv_.Array.items[3]);
        }
        if (jv.Object.get("baseColorTexture")) |jv_| {
            try self.parseTextureInfo(&data.*.?.base_color_texture, jv_);
        }
        if (jv.Object.get("metallicFactor")) |jv_| {
            data.*.?.metallic_factor = jsonValueToFloat(f32, jv_);
        }
        if (jv.Object.get("roughnessFactor")) |jv_| {
            data.*.?.roughness_factor = jsonValueToFloat(f32, jv_);
        }
        if (jv.Object.get("metallicRoughnessTexture")) |jv_| {
            try self.parseTextureInfo(&data.*.?.metallic_roughness_texture, jv_);
        }
        if (jv.Object.get("extensions")) |jv_| {
            data.*.?.extensions = try jsonValueDeepClone(self.allocator, jv_);
        }
        if (jv.Object.get("extras")) |jv_| {
            data.*.?.extras = try jsonValueDeepClone(self.allocator, jv_);
        }
    }

    fn freePbrMetallicRoughness(self: *Self, data: *PbrMetallicRoughness) void {
        if (data.base_color_texture) |*bct| self.freeTextureInfo(bct);
        if (data.metallic_roughness_texture) |*mrt| self.freeTextureInfo(mrt);
        if (data.extensions) |*jv| jsonValueFreeClone(self.allocator, jv);
        if (data.extras) |*jv| jsonValueFreeClone(self.allocator, jv);
    }

    fn parsePerspective(self: *Self, data: *?Perspective, jv: json.Value) !void {
        const yfov = jv.Object.get("yfov") orelse return Error.InvalidCamera;
        const znear = jv.Object.get("znear") orelse return Error.InvalidCamera;
        data.* = .{
            .yfov = jsonValueToFloat(f32, yfov),
            .znear = jsonValueToFloat(f32, znear),
        };
        if (jv.Object.get("aspectRatio")) |jv_| {
            data.*.?.aspect_ratio = jsonValueToFloat(f32, jv_);
        }
        if (jv.Object.get("zfar")) |jv_| {
            data.*.?.zfar = jsonValueToFloat(f32, jv_);
        }
        if (jv.Object.get("extensions")) |jv_| {
            data.*.?.extensions = try jsonValueDeepClone(self.allocator, jv_);
        }
        if (jv.Object.get("extras")) |jv_| {
            data.*.?.extras = try jsonValueDeepClone(self.allocator, jv_);
        }
    }

    fn freePerspective(self: *Self, data: *Perspective) void {
        if (data.extensions) |*jv| jsonValueFreeClone(self.allocator, jv);
        if (data.extras) |*jv| jsonValueFreeClone(self.allocator, jv);
    }

    fn parsePrimitive(self: *Self, data: *Primitive, jv: json.Value) !void {
        const attributes = jv.Object.get("attributes") orelse return Error.InvalidMesh;
        data.* = .{
            .attributes = Primitive.AttributeMap.init(self.allocator),
        };

        {
            var iter = attributes.Object.iterator();
            while (iter.next()) |entry| {
                try data.*.attributes.put(entry.key, @intCast(usize, entry.value.Integer));
            }
        }

        if (jv.Object.get("indices")) |jv_| {
            data.indices = @intCast(usize, jv_.Integer);
        }
        if (jv.Object.get("material")) |jv_| {
            data.material = @intCast(usize, jv_.Integer);
        }
        if (jv.Object.get("mode")) |jv_| {
            var mode: Primitive.Mode = undefined;
            if (std.mem.eql(u8, jv_.String, "POINTS")) {
                mode = .Points;
            } else if (std.mem.eql(u8, jv_.String, "LINES")) {
                mode = .Lines;
            } else if (std.mem.eql(u8, jv_.String, "LINE_LOOP")) {
                mode = .LineLoop;
            } else if (std.mem.eql(u8, jv_.String, "LINE_STRIP")) {
                mode = .LineStrip;
            } else if (std.mem.eql(u8, jv_.String, "TRIANGLES")) {
                mode = .Triangles;
            } else if (std.mem.eql(u8, jv_.String, "TRIANGLE_STRIP")) {
                mode = .TriangleStrip;
            } else if (std.mem.eql(u8, jv_.String, "TRIANGLE_FAN")) {
                mode = .TriangleFan;
            } else {
                return Error.InvalidMesh;
            }
            data.mode = mode;
        }
        if (jv.Object.get("targets")) |jv_| {
            var targets = try self.allocator.alloc(Primitive.AttributeMap, jv_.Array.items.len);
            for (jv_.Array.items) |j_target, i| {
                targets[i] = Primitive.AttributeMap.init(self.allocator);

                var iter = j_target.Object.iterator();
                while (iter.next()) |entry| {
                    try targets[i].put(entry.key, @intCast(usize, entry.value.Integer));
                }
            }
            data.targets = targets;
        }
        if (jv.Object.get("extensions")) |jv_| {
            data.extensions = try jsonValueDeepClone(self.allocator, jv_);
        }
        if (jv.Object.get("extras")) |jv_| {
            data.extras = try jsonValueDeepClone(self.allocator, jv_);
        }
    }

    fn freePrimitive(self: *Self, data: *Primitive) void {
        data.attributes.deinit();
        if (data.targets) |targets| {
            for (targets) |*target| {
                target.deinit();
            }
            self.allocator.free(targets);
        }
        if (data.extensions) |*jv| jsonValueFreeClone(self.allocator, jv);
        if (data.extras) |*jv| jsonValueFreeClone(self.allocator, jv);
    }

    fn parseSamplers(self: *Self, gltf: *GlTF, j_array: json.Value) !void {
        const len = j_array.Array.items.len;
        gltf.samplers = try self.allocator.alloc(Sampler, len);

        for (j_array.Array.items) |jv, i| {
            var curr = &gltf.samplers.?[i];
            curr.* = .{};
            if (jv.Object.get("minFilter")) |jv_| {
                curr.min_filter = @intToEnum(Sampler.Filter, @intCast(c.GLenum, jv_.Integer));
            }
            if (jv.Object.get("magFilter")) |jv_| {
                curr.mag_filter = @intToEnum(Sampler.Filter, @intCast(c.GLenum, jv_.Integer));
            }
            if (jv.Object.get("wrapS")) |jv_| {
                curr.wrap_s = @intToEnum(Sampler.Wrap, @intCast(c.GLenum, jv_.Integer));
            }
            if (jv.Object.get("wrapT")) |jv_| {
                curr.wrap_t = @intToEnum(Sampler.Wrap, @intCast(c.GLenum, jv_.Integer));
            }
            if (jv.Object.get("name")) |jv_| {
                curr.name = try self.allocator.dupe(u8, jv_.String);
            }
            if (jv.Object.get("extensions")) |jv_| {
                curr.extensions = try jsonValueDeepClone(self.allocator, jv_);
            }
            if (jv.Object.get("extras")) |jv_| {
                curr.extras = try jsonValueDeepClone(self.allocator, jv_);
            }
        }
    }

    fn freeSamplers(self: *Self, gltf: *GlTF) void {
        if (gltf.samplers) |objs| {
            for (objs) |*obj| {
                if (obj.name) |name| self.allocator.free(name);
                if (obj.extensions) |*jv| jsonValueFreeClone(self.allocator, jv);
                if (obj.extras) |*jv| jsonValueFreeClone(self.allocator, jv);
            }
            self.allocator.free(objs);
        }
    }

    fn parseScenes(self: *Self, gltf: *GlTF, j_array: json.Value) !void {
        const len = j_array.Array.items.len;
        gltf.scenes = try self.allocator.alloc(Scene, len);

        for (j_array.Array.items) |jv, i| {
            var curr = &gltf.scenes.?[i];
            curr.* = .{};
            if (jv.Object.get("nodes")) |jv_| {
                curr.nodes = try self.allocator.alloc(usize, jv_.Array.items.len);
                for (jv_.Array.items) |item, ai| {
                    curr.nodes.?[ai] = @intCast(usize, item.Integer);
                }
            }
            if (jv.Object.get("name")) |jv_| {
                curr.name = try self.allocator.dupe(u8, jv_.String);
            }
            if (jv.Object.get("extensions")) |jv_| {
                curr.extensions = try jsonValueDeepClone(self.allocator, jv_);
            }
            if (jv.Object.get("extras")) |jv_| {
                curr.extras = try jsonValueDeepClone(self.allocator, jv_);
            }
        }
    }

    fn freeScenes(self: *Self, gltf: *GlTF) void {
        if (gltf.scenes) |objs| {
            for (objs) |*obj| {
                if (obj.nodes) |nodes| self.allocator.free(nodes);
                if (obj.name) |name| self.allocator.free(name);
                if (obj.extensions) |*jv| jsonValueFreeClone(self.allocator, jv);
                if (obj.extras) |*jv| jsonValueFreeClone(self.allocator, jv);
            }
            self.allocator.free(objs);
        }
    }

    fn parseTextures(self: *Self, gltf: *GlTF, j_array: json.Value) !void {
        const len = j_array.Array.items.len;
        gltf.textures = try self.allocator.alloc(Texture, len);

        for (j_array.Array.items) |jv, i| {
            var curr = &gltf.textures.?[i];
            curr.* = .{};
            if (jv.Object.get("source")) |jv_| {
                curr.source = @intCast(usize, jv_.Integer);
            }
            if (jv.Object.get("sampler")) |jv_| {
                curr.sampler = @intCast(usize, jv_.Integer);
            }
            if (jv.Object.get("name")) |jv_| {
                curr.name = try self.allocator.dupe(u8, jv_.String);
            }
            if (jv.Object.get("extensions")) |jv_| {
                curr.extensions = try jsonValueDeepClone(self.allocator, jv_);
            }
            if (jv.Object.get("extras")) |jv_| {
                curr.extras = try jsonValueDeepClone(self.allocator, jv_);
            }
        }
    }

    fn freeTextures(self: *Self, gltf: *GlTF) void {
        if (gltf.textures) |objs| {
            for (objs) |*obj| {
                if (obj.name) |name| self.allocator.free(name);
                if (obj.extensions) |*jv| jsonValueFreeClone(self.allocator, jv);
                if (obj.extras) |*jv| jsonValueFreeClone(self.allocator, jv);
            }
            self.allocator.free(objs);
        }
    }

    fn parseTextureInfo(self: *Self, data: *?TextureInfo, jv: json.Value) !void {
        const index = jv.Object.get("index") orelse return Error.InvalidMaterial;
        data.* = .{
            .index = @intCast(usize, index.Integer),
        };

        if (jv.Object.get("texCoord")) |jv_| {
            data.*.?.tex_coord = @intCast(usize, jv_.Integer);
        }
        if (jv.Object.get("extensions")) |jv_| {
            data.*.?.extensions = try jsonValueDeepClone(self.allocator, jv_);
        }
        if (jv.Object.get("extras")) |jv_| {
            data.*.?.extras = try jsonValueDeepClone(self.allocator, jv_);
        }
    }

    fn freeTextureInfo(self: *Self, data: *TextureInfo) void {
        if (data.extensions) |*jv| jsonValueFreeClone(self.allocator, jv);
        if (data.extras) |*jv| jsonValueFreeClone(self.allocator, jv);
    }
};

test "gltf" {
    const testing = std.testing;
    const suz = @import("content.zig").gltf.suzanne;
    var parser = GlTF_Parser.init(testing.allocator);
    defer parser.deinit();

    var gltf = try parser.parseFromString(suz);
    defer parser.freeParse(&gltf);

    std.log.warn("{}", .{gltf.samplers.?[0]});
    for (gltf.nodes.?) |item| {
        std.log.warn("\n{}\n\n", .{item});
    }
}
