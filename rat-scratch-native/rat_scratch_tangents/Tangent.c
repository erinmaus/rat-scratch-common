#include <string.h>

#include "../rat_scratch_native_common/RatScratch.h"
#include "Tangent.h"
#include "lib/MikkTSpace/mikktspace.h"

int rs_getNumFaces(const SMikkTSpaceContext *context)
{
	RatScratchTangentUserdata *userdata = (RatScratchTangentUserdata *)context->m_pUserData;
	return userdata->indexInfo.count / 3;
}

int rs_getNumVerticesOfFace(const SMikkTSpaceContext *context, const int face)
{
	return 3;
}

void rs_getPosition(const SMikkTSpaceContext *context, float *result, const int face, const int index)
{
	RatScratchTangentUserdata *userdata = (RatScratchTangentUserdata *)context->m_pUserData;
	const uint32_t i = userdata->indexInfo.indices[face * 3 + index];

	const float *input = (const float *)((const uint8_t *)userdata->inputVertexInfo.position.value +
										 userdata->inputVertexInfo.position.stride * i);
	result[0] = input[0];
	result[1] = input[1];
	result[2] = input[2];
}

void rs_getNormal(const SMikkTSpaceContext *context, float *result, const int face, const int index)
{
	RatScratchTangentUserdata *userdata = (RatScratchTangentUserdata *)context->m_pUserData;
	const uint32_t i = userdata->indexInfo.indices[face * 3 + index];

	const float *input = (const float *)((const uint8_t *)userdata->inputVertexInfo.normal.value +
										 userdata->inputVertexInfo.normal.stride * i);
	result[0] = input[0];
	result[1] = input[1];
	result[2] = input[2];
}

void rs_getTexCoord(const SMikkTSpaceContext *context, float *result, const int face, const int index)
{
	RatScratchTangentUserdata *userdata = (RatScratchTangentUserdata *)context->m_pUserData;
	const uint32_t i = userdata->indexInfo.indices[face * 3 + index];

	const float *input = (const float *)((const uint8_t *)userdata->inputVertexInfo.textureCoordinate.value +
										 userdata->inputVertexInfo.textureCoordinate.stride * i);
	result[0] = input[0];
	result[1] = input[1];
}

void rs_setTSpaceBasic(const SMikkTSpaceContext *context, const float *tangent, const float sign, const int face,
					   const int index)
{
	RatScratchTangentUserdata *userdata = (RatScratchTangentUserdata *)context->m_pUserData;
	const uint32_t i = userdata->indexInfo.indices[face * 3 + index];

	float *output = (float *)((const uint8_t *)userdata->outputVertexInfo.tangent.value +
							  userdata->outputVertexInfo.tangent.stride * i);

	output[0] = tangent[0];
	output[1] = tangent[1];
	output[2] = tangent[2];
	output[3] = sign;
}

RAT_SCRATCH_API int rat_generateTangents(uint32_t *indices, size_t indexCount, float *position, size_t positionStride,
										 float *normal, size_t normalStride, float *textureCoordinate,
										 size_t textureCoordinateStride, float *tangent, size_t tangentStride)
{
	RatScratchTangentUserdata userdata = {0};

	userdata.indexInfo.indices = indices;
	userdata.indexInfo.count = indexCount;

	userdata.inputVertexInfo.position.value = position;
	userdata.inputVertexInfo.position.stride = positionStride ? positionStride : sizeof(float) * 3;

	userdata.inputVertexInfo.normal.value = normal;
	userdata.inputVertexInfo.normal.stride = normalStride ? normalStride : sizeof(float) * 3;

	userdata.inputVertexInfo.textureCoordinate.value = textureCoordinate;
	userdata.inputVertexInfo.textureCoordinate.stride =
		textureCoordinateStride ? textureCoordinateStride : sizeof(float) * 2;

	userdata.outputVertexInfo.tangent.value = tangent;
	userdata.outputVertexInfo.tangent.stride = tangentStride ? tangentStride : sizeof(float) * 4;

	SMikkTSpaceInterface interface = {0};
	interface.m_getNumFaces = &rs_getNumFaces;
	interface.m_getNumVerticesOfFace = &rs_getNumVerticesOfFace;
	interface.m_getPosition = &rs_getPosition;
	interface.m_getNormal = &rs_getNormal;
	interface.m_getTexCoord = &rs_getTexCoord;
	interface.m_setTSpaceBasic = &rs_setTSpaceBasic;

	SMikkTSpaceContext context = {0};
	context.m_pInterface = &interface;
	context.m_pUserData = &userdata;

	return genTangSpaceDefault(&context);
}
