package handler

import (
	"actlabs-hub/internal/auth"
	"actlabs-hub/internal/entity"
	"net/http"

	"github.com/gin-gonic/gin"
)

type serverHandler struct {
	serverService entity.ServerService
}

func NewServerHandler(r *gin.RouterGroup, serverService entity.ServerService) {
	handler := &serverHandler{
		serverService: serverService,
	}

	r.PUT("/server/register/:subscriptionId", handler.RegisterSubscription)

	r.GET("/server", handler.GetServer)
	r.PUT("/server", handler.DeployServer)
	r.PUT("/server/update", handler.UpdateServer)
	r.DELETE("/server", handler.DestroyServer)

	r.PUT("/server/activity/:userPrincipalName", handler.UpdateActivityStatus)
}

func (h *serverHandler) RegisterSubscription(c *gin.Context) {
	subscriptionId := c.Param("subscriptionId")
	userPrincipalName, err := auth.GetUserPrincipalFromToken(c.GetHeader("Authorization"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "not authorized or invalid token"})
	}

	userPrincipalId, err := auth.GetUserObjectIdFromToken(c.GetHeader("Authorization"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "not authorized or invalid token"})
	}

	if err := h.serverService.RegisterSubscription(subscriptionId, userPrincipalName, userPrincipalId); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(200, gin.H{"status": "success"})
}

func (h *serverHandler) GetServer(c *gin.Context) {

	userPrincipalName, err := auth.GetUserPrincipalFromToken(c.GetHeader("Authorization"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "not authorized or invalid token"})
	}

	server, err := h.serverService.GetServer(userPrincipalName)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(200, server)
}

func (h *serverHandler) UpdateServer(c *gin.Context) {
	server := entity.Server{}
	if err := c.ShouldBindJSON(&server); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	if !auth.VerifyUserObjectId(server.UserPrincipalId, c.GetHeader("Authorization")) {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid request"})
		return
	}

	if err := h.serverService.UpdateServer(server); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(200, server)
}

func (h *serverHandler) DeployServer(c *gin.Context) {
	server := entity.Server{}
	if err := c.ShouldBindJSON(&server); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	if !auth.VerifyUserObjectId(server.UserPrincipalId, c.GetHeader("Authorization")) {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid request"})
		return
	}

	server, err := h.serverService.DeployServer(server)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(200, server)
}

func (h *serverHandler) DestroyServer(c *gin.Context) {
	userPrincipalName, err := auth.GetUserPrincipalFromToken(c.GetHeader("Authorization"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "not authorized or invalid token"})
	}

	err = h.serverService.DestroyServer(userPrincipalName)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(200, gin.H{"status": "success"})
}

func (h *serverHandler) UpdateActivityStatus(c *gin.Context) {
	userPrincipalName := c.Param("userPrincipalName")

	if !auth.VerifyUserPrincipalName(userPrincipalName, c.GetHeader("Authorization")) {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid request"})
		return
	}

	if err := h.serverService.UpdateActivityStatus(userPrincipalName); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(200, gin.H{"status": "success"})
}
