-- Calculates base Y coordinate of a cloud from a circle of clouds near horizon
CalculateHorizonCloudYCoordinate = ({
  spa = function (dir) return 40 end,
  ks_laguna_seca = function (dir) return 32 end
})[ac.getTrackID()] or function (pos) return 22 end
