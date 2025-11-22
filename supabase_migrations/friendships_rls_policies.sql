-- RLS Policies for friendships table
-- These policies allow users to manage their own friendships

-- Enable RLS on friendships table
ALTER TABLE public.friendships ENABLE ROW LEVEL SECURITY;

-- Policy: Users can view friendships where they are involved
CREATE POLICY "Users can view own friendships"
ON public.friendships
FOR SELECT
TO authenticated
USING (
  user_a_id = auth.uid() OR user_b_id = auth.uid()
);

-- Policy: Users can create friend requests
CREATE POLICY "Users can create friend requests"
ON public.friendships
FOR INSERT
TO authenticated
WITH CHECK (
  requester_id = auth.uid() AND
  (user_a_id = auth.uid() OR user_b_id = auth.uid())
);

-- Policy: Users can update friendships where they are involved
-- (for accepting/rejecting requests)
CREATE POLICY "Users can update own friendships"
ON public.friendships
FOR UPDATE
TO authenticated
USING (
  user_a_id = auth.uid() OR user_b_id = auth.uid()
)
WITH CHECK (
  user_a_id = auth.uid() OR user_b_id = auth.uid()
);

-- Policy: Users can delete friendships where they are involved
-- (for unfriending or canceling requests)
CREATE POLICY "Users can delete own friendships"
ON public.friendships
FOR DELETE
TO authenticated
USING (
  user_a_id = auth.uid() OR user_b_id = auth.uid()
);




