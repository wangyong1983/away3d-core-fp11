package away3d.core.pick
{
	import flash.geom.Vector3D;
	
	import away3d.arcane;
	import away3d.containers.Scene3D;
	import away3d.containers.View3D;
	import away3d.core.data.EntityListItem;
	import away3d.core.traverse.EntityCollector;
	import away3d.core.traverse.RaycastCollector;
	import away3d.entities.Entity;

	use namespace arcane;
	
	/**
	 * Picks a 3d object from a view or scene by 3D raycast calculations.
	 * Performs an initial coarse boundary calculation to return a subset of entities whose bounding volumes intersect with the specified ray,
	 * then triggers an optional picking collider on individual entity objects to further determine the precise values of the picking ray collision.
	 */
	public class RaycastPicker implements IPicker
	{
		// TODO: add option of finding best hit?

		private var _findClosestCollision:Boolean;
		private var _raycastCollector:RaycastCollector = new RaycastCollector();
		
		protected var _entities:Vector.<Entity>;
		protected var _numEntities:uint;
		protected var _hasCollisions:Boolean;

		/**
		 * Creates a new <code>RaycastPicker</code> object.
		 * 
		 * @param findClosestCollision Determines whether the picker searches for the closest bounds collision along the ray,
		 * or simply returns the first collision encountered Defaults to false.
		 */
		public function RaycastPicker( findClosestCollision:Boolean ) {

			_findClosestCollision = findClosestCollision;
			_entities = new Vector.<Entity>();
		}

		/**
		 * @inheritDoc
		 */
		public function getViewCollision(x:Number, y:Number, view:View3D):PickingCollisionVO
		{
			//cast ray through the collection of entities on the view
			var collector:EntityCollector = view.entityCollector;
			var i:uint;

			if( collector.numMouseEnableds == 0 )
				return null;

			//update ray
			var rayPosition:Vector3D = view.unproject( x, y, 0 );
			var rayDirection:Vector3D = view.unproject( x, y, 1 );
			rayDirection = rayDirection.subtract( rayPosition );

			// Perform ray-bounds collision checks.
			_numEntities = 0;
			var node : EntityListItem = collector.entityHead;
			var entity : Entity;
			while (node) {
				entity = node.entity;
				
				// If collision detected, store in new data set.
				if( entity.isVisible && entity._ancestorsAllowMouseEnabled && entity.mouseEnabled && entity.isIntersectingRay(rayPosition, rayDirection ))
						_entities[_numEntities++] = entity;
				
				node = node.next;
			}
			
			//early out if no collisions detected
			if( !_numEntities )
				return null;
			
			return getPickingCollisionVO();
		}

		/**
		 * @inheritDoc
		 */
		public function getSceneCollision(position:Vector3D, direction:Vector3D, scene:Scene3D):PickingCollisionVO
		{
			//setup ray vectors
			_raycastCollector.rayPosition = position;
			_raycastCollector.rayDirection = direction;
			
			// collect stuff to test
			scene.traversePartitions(_raycastCollector);
			
			_numEntities = 0;
			var node : EntityListItem = _raycastCollector.entityHead;
			var entity : Entity;
			while (node) {
				entity = node.entity;
				
				_entities[_numEntities++] = entity;
				
				node = node.next;
			}
			
			//early out if no collisions detected
			if( !_numEntities )
				return null;
			
			return getPickingCollisionVO();
		}

		private function sortOnNearT( entity1:Entity, entity2:Entity ):Number
		{
			return entity1.pickingCollisionVO.rayEntryDistance > entity2.pickingCollisionVO.rayEntryDistance ? 1 : -1;
		}
		
		private function getPickingCollisionVO():PickingCollisionVO
		{
			// trim before sorting
			_entities.length = _numEntities;

			// Sort entities from closest to furthest.
			_entities = _entities.sort( sortOnNearT );

			// ---------------------------------------------------------------------
			// Evaluate triangle collisions when needed.
			// Replaces collision data provided by bounds collider with more precise data.
			// ---------------------------------------------------------------------

			var shortestCollisionDistance:Number = Number.MAX_VALUE;
			var bestCollisionVO:PickingCollisionVO;
			var pickingCollisionVO:PickingCollisionVO;
			var entity:Entity;
			var i:uint;
			
			for( i = 0; i < _numEntities; ++i ) {
				entity = _entities[i];
				pickingCollisionVO = entity._pickingCollisionVO;
				if(entity.pickingCollider) {
					// If a collision exists, update the collision data and stop all checks.
					if( (bestCollisionVO == null || pickingCollisionVO.rayEntryDistance < bestCollisionVO.rayEntryDistance) && entity.collidesBefore(shortestCollisionDistance, _findClosestCollision) ) {
						shortestCollisionDistance = pickingCollisionVO.rayEntryDistance;
						bestCollisionVO = pickingCollisionVO;
						if (!_findClosestCollision) {
							updateLocalPosition(pickingCollisionVO);
							return pickingCollisionVO;
						}
					}
				}
				else if (bestCollisionVO == null || pickingCollisionVO.rayEntryDistance < bestCollisionVO.rayEntryDistance) { // A bounds collision with no triangle collider stops all checks.
					// Note: rayEntryDistances of 0 mean a collision caused by the ray starting inside the bounds.
					// This makes the object eligible for triangle picking but should not represent a successful pick
					// if the object's picker is bounds only.
					if( pickingCollisionVO.rayEntryDistance != 0 ) {
						updateLocalPosition( pickingCollisionVO );
						return pickingCollisionVO;
					}
				}
			}

			return bestCollisionVO;
		}

		private function updateLocalPosition(pickingCollisionVO : PickingCollisionVO) : void
		{
			var collisionPos : Vector3D = pickingCollisionVO.localPosition ||= new Vector3D();
			var rayDir : Vector3D = pickingCollisionVO.localRayDirection;
			var rayPos : Vector3D = pickingCollisionVO.localRayPosition;
			var t : Number = pickingCollisionVO.rayEntryDistance;
			collisionPos.x = rayPos.x + t*rayDir.x;
			collisionPos.y = rayPos.y + t*rayDir.y;
			collisionPos.z = rayPos.z + t*rayDir.z;
		}
	}
}
