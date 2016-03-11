Store              = require 'fluxible/addons/BaseStore'
localStorage       = require './local-storage'
config             = require '../config'
XhrPromise         = require '../util/xhr-promise'
orderBy            = require 'lodash/orderBy'
sortBy             = require 'lodash/sortBy'
uniqWith          = require 'lodash/uniqWith'
takeRight          = require 'lodash/takeRight'
SuggestionUtils    = require '../util/suggestion-utils'

currentLocation =
  type: "CurrentLocation", properties:
    labelId: "own-position"
    layer: "currentPosition"

sort = (features) ->
  sortBy features, (feature) ->
    config.autoSuggest.sortOrder[feature.properties.layer] || config.autoSuggest.sortOthers

uniq = (features) ->
  uniqWith features, (feat1, feat2) ->
    SuggestionUtils.getLabel(feat1.properties) == SuggestionUtils.getLabel(feat2.properties) # or perhaps coords instead?

addCurrentPositionIfEmpty = (features) ->
  if features.length == 0
    features.push currentLocation
  features

addOldSearches = (features, input) ->
  if input?.length >= 0
    matchingOldSearches = getSearches().filter (search) -> search.address.toLowerCase().indexOf(input.toLowerCase()) > -1
  else
    matchingOldSearches = getSearches()

  results = takeRight(matchingOldSearches, 10).map (item) ->
    type: "OldSearch"
    properties:
      label: item.address
      layer: 'oldSearch'
    geometry: item.geometry
  features.concat results

getSearches = () ->
  saved = localStorage.getItem "saved-searches"
  if saved == null
    saved = []
  else
    saved = JSON.parse(saved)
  saved

getPeliasDataOrEmptyArray = (input, geolocation) ->
  if input == undefined or input == null or input.trim().length < 3
    return Promise.resolve []

  if config.autoSuggest.locationAware && geolocation.hasLocation
    opts = Object.assign text: input, config.searchParams, "focus.point.lat": geolocation.lat, "focus.point.lon": geolocation.lon
  else
    opts = Object.assign text: input, config.searchParams

  return XhrPromise.getJson(config.URL.PELIAS, opts).then (res) -> res.features

class SearchStore extends Store
  @storeName: 'SearchStore'

  constructor: (dispatcher) ->
    super(dispatcher)
    @modalOpen = false
    @actionTarget = undefined
    @position = undefined
    @placeholder = undefined
    @action = undefined

  isModalOpen: () =>
    @modalOpen

  getActionTarget: () =>
    @actionTarget

  getAction: () =>
    @action

  getPlaceholder: () =>
    @placeholder

  getPosition: () =>
    @position

  # Usually we don't do async stuff in stores nor do we make XHR request.
  # However, in this case it better to keep all this logic in one place
  # And make all data fetching here
  getSuggestions: (input, geoLocation, cb) =>
    getPeliasDataOrEmptyArray(input, geoLocation)
    .then addCurrentPositionIfEmpty
    .then (suggestions) -> addOldSearches(suggestions, input)
    .then sort
    .then uniq
    .then (suggestions) -> cb(suggestions)
    .catch (e) ->
      console.error("error occurred", e)

  openSearch: (props) ->
    @modalOpen = true
    @actionTarget = props.actionTarget
    @position = props.position
    @placeholder = props.placeholder
    @action = props.action
    @emitChange(props)

  closeSearch: () ->
    @modalOpen = false
    @actionTarget = undefined
    @position = undefined
    @placeholder = undefined
    @action = undefined
    @emitChange()

  # storage (sorted by count desc):
  # [
  #  {
  #   "address": "Espoo, Espoo",
  #   "coordinates" :[]
  #   "count": 1
  #  }
  # ]
  #
  # destination
  # {
  #  "address": "Espoo, Espoo",
  #  coordinates :[]
  # }
  saveSearch: (destination) ->
    searches = getSearches()

    found = searches.filter (storedDestination) ->
      storedDestination.address == destination.address

    switch found.length
      when 0 then searches.push Object.assign count: 1, destination
      when 1 then found[0].count = found[0].count + 1
      else console.error "too many matches", found

    localStorage.setItem "saved-searches", orderBy searches, "count", "desc"

  @handlers:
    "OpenSearch": 'openSearch'
    "CloseSearch": 'closeSearch'
    "SaveSearch": 'saveSearch'

module.exports = SearchStore
