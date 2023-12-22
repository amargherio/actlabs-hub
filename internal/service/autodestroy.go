package service

import (
	"actlabs-hub/internal/config"
	"actlabs-hub/internal/entity"
	"actlabs-hub/internal/helper"
	"context"
	"time"

	"golang.org/x/exp/slog"
)

type AutoDestroyService struct {
	appConfig        *config.Config
	serverRepository entity.ServerRepository
}

func NewAutoDestroyService(appConfig *config.Config, repo entity.ServerRepository) *AutoDestroyService {
	return &AutoDestroyService{
		appConfig:        appConfig,
		serverRepository: repo,
	}
}

func (s *AutoDestroyService) MonitorAndDestroyInactiveServers(ctx context.Context) {
	helper.Recoverer(100, "MonitorAndDestroyInactiveServers", func() {
		ticker := time.NewTicker(time.Duration(s.appConfig.ActlabsHubAutoDestroyPollingIntervalSeconds) * time.Second)
		defer ticker.Stop()

		for {
			select {
			case <-ctx.Done():
				// Context was cancelled or the application finished, so stop the goroutine
				return
			case <-ticker.C:
				// Every minute, check for servers to destroy
				if err := s.DestroyIdleServers(ctx); err != nil {
					slog.Error("not able to destroy idle servers", err)
				}
			}
		}
	})
}

func (s *AutoDestroyService) DestroyIdleServers(ctx context.Context) error {
	slog.Info("polling for servers to destroy")
	allServers, err := s.serverRepository.GetAllServersFromDatabase(ctx)
	if err != nil {
		slog.Error("not able to get all servers", err)
		return err
	}

	for _, server := range allServers {

		lastActivityTime, err := time.Parse(time.RFC3339, server.LastUserActivityTime)
		if err != nil {
			slog.Error("not able to parse last activity time", err)
			continue
		}

		if server.AutoDestroy &&
			server.Status == entity.ServerStatusRunning &&
			time.Since(lastActivityTime) > time.Duration(server.InactivityDurationInMinutes)*time.Minute &&
			s.VerifyServerIdle(server) {
			if err := s.DestroyServer(server); err != nil {
				slog.Error("not able to destroy server",
					slog.String("userPrincipalName", server.UserPrincipalName),
					slog.String("subscriptionId", server.SubscriptionId),
					slog.String("status", string(server.Status)),
					slog.String("error", err.Error()),
				)
			}
		}
	}

	return nil
}

func (s *AutoDestroyService) VerifyServerIdle(server entity.Server) bool {
	isIdle, err := s.serverRepository.EnsureServerIdle(server)
	if err != nil {
		slog.Error("not able to verify server idle", err)
		return false
	}

	slog.Info("server idle status",
		slog.String("userPrincipalName", server.UserPrincipalName),
		slog.Bool("isIdle", isIdle),
	)

	return isIdle
}

func (s *AutoDestroyService) DestroyServer(server entity.Server) error {
	slog.Info("destroying server",
		slog.String("userPrincipalName", server.UserPrincipalName),
		slog.String("subscriptionId", server.SubscriptionId),
		slog.String("status", string(server.Status)),
		slog.String("lastActivityTime", server.LastUserActivityTime),
		slog.Bool("autoDestroy", server.AutoDestroy),
	)

	if err := s.serverRepository.DestroyAzureContainerGroup(server); err != nil {
		return err
	}

	// update server status in database
	server.Status = entity.ServerStatusAutoDestroyed
	server.DestroyedAtTime = time.Now().Format(time.RFC3339)
	if err := s.serverRepository.UpsertServerInDatabase(server); err != nil {
		return err
	}

	slog.Info("server destroyed",
		slog.String("userPrincipalName", server.UserPrincipalName),
		slog.String("subscriptionId", server.SubscriptionId),
		slog.String("status", string(server.Status)),
		slog.String("lastActivityTime", server.LastUserActivityTime),
		slog.Bool("autoDestroy", server.AutoDestroy),
	)

	return nil
}
